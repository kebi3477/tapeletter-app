import 'package:tapeletter_app/data/model/api_error.dart';
import 'package:tapeletter_app/data/model/auth_dto.dart';
import 'package:tapeletter_app/data/model/delivery_dto.dart';
import 'package:tapeletter_app/data/model/friend_dto.dart';
import 'package:tapeletter_app/data/model/mappers.dart';
import 'package:tapeletter_app/data/model/me_dto.dart';
import 'package:tapeletter_app/data/model/recording_dto.dart';
import 'package:tapeletter_app/data/model/shelf_dto.dart';
import 'package:tapeletter_app/data/model/shop_dto.dart';
import 'package:tapeletter_app/domain/models/recording.dart';
import 'package:tapeletter_app/domain/models/shop.dart';
import 'package:tapeletter_app/domain/models/sent_tape.dart';
import 'package:tapeletter_app/domain/models/tape_tag.dart';
import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// 계약서(tapeletter-api/docs/api.md)의 예시 JSON을 그대로 읽는다.
void main() {
  test('Me (§2) — unopenedCount가 없어도 읽는다', () {
    final me = MeDto.fromJson({
      'id': 'd3d62aa5',
      'name': '민경',
      'credits': 120,
      'drawer': {'stored': 11, 'cap': 12, 'full': false},
      'tapes': [
        {'tapeType': 15, 'qty': null},
        {'tapeType': 60, 'qty': 2},
        {'tapeType': 180, 'qty': 0},
      ],
      'stats': {'receivedCount': 11, 'sentCount': 4, 'friendCount': 6},
      'providers': ['kakao'],
      'notificationsEnabled': true,
      'createdAt': '2026-09-01T03:00:00.000Z',
    }).toDomain();
    expect(me.owned, {TapeType.m1: 2, TapeType.m3: 0});
    expect(me.drawer.unopenedCount, 0);
  });

  test('ShelfItem (§2)', () {
    final x = ShelfItemDto.fromJson({
      'id': 'd1',
      'sender': {'userId': 'u1', 'name': '지현'},
      'tapeType': 60,
      'durationMs': 34000,
      'tag': 'birthday',
      'sentAt': '2026-09-24T09:00:00.000Z',
      'opened': false,
      'openedAt': null,
      'viaLink': false,
      'groupId': null,
    }).toDomain();
    expect(x.from, '지현');
    expect(x.senderId, 'u1');
    expect(x.tag, TapeTag.birthday);
    expect(x.duration, const Duration(seconds: 34));
    expect(x.groupId, isNull);
    expect(x.memo, isNull, reason: 'memo가 없는 옛 응답도 읽는다');
  });

  test('ShelfItem.memo — 나에게만 보이는 메모', () {
    final j = {
      'id': 'd1',
      'sender': {'userId': 'u1', 'name': '지현', 'nickname': null},
      'tapeType': 60,
      'durationMs': 34000,
      'tag': null,
      'sentAt': '2026-09-24T09:00:00.000Z',
      'opened': true,
      'openedAt': '2026-09-24T10:00:00.000Z',
      'viaLink': false,
      'groupId': null,
      'memo': '생일 아침',
    };
    final dto = ShelfItemDto.fromJson(j);
    expect(dto.toDomain().memo, '생일 아침');
    expect(ShelfItemDto.fromJson(dto.toJson()).memo, '생일 아침');
    expect(dto.copyWith(memo: () => null).memo, isNull);
  });

  test('SentTape (§2) 링크 대기', () {
    final s = SentTapeDto.fromJson({
      'id': 'd2',
      'recipient': null,
      'linkName': '유진',
      'tapeType': 15,
      'durationMs': 20000,
      'tag': 'thinking',
      'sentAt': '2026-09-22T09:00:00.000Z',
      'status': 'link_pending',
      'claimedAt': null,
      'openedAt': null,
      'share': {
        'url': 'https://x/t/abc',
        'expiresAt': '2026-09-29T09:00:00.000Z',
      },
    }).toDomain();
    expect(s.status, SentStatus.linkPending);
    expect(s.to, '유진');
    expect(s.link, isTrue);
    expect(s.claimed, isFalse);
  });

  test('Recording (§9) preview', () {
    final r = RecordingDto.fromJson({
      'id': 'r1',
      'tapeType': 60,
      'durationMs': 95000,
      'status': 'ready',
      'preview': {'url': 'https://p', 'expiresAt': '2026-09-25T06:44:46.549Z'},
    }).toDomain();
    expect(r.status, RecordingStatus.ready);
    expect(r.previewUrl, 'https://p');
    expect(r.duration, const Duration(seconds: 95));
  });

  test('POST /deliveries 요청 본문: recipientId 또는 linkName (tag는 보내지 않음)', () {
    expect(
      const CreateDeliveryRequest(
        recordingId: 'r1',
        recipientId: 'u1',
      ).toJson(),
      {'recordingId': 'r1', 'recipientId': 'u1'},
    );
    expect(
      const CreateDeliveryRequest(recordingId: 'r1', linkName: '유진').toJson(),
      {'recordingId': 'r1', 'linkName': '유진'},
    );
  });

  test('응답의 tag는 null일 수 있다', () {
    final x = ShelfItemDto.fromJson({
      'id': 'd1',
      'sender': {'userId': 'u1', 'name': '지현'},
      'tapeType': 15,
      'durationMs': 20000,
      'tag': null,
      'sentAt': '2026-09-24T09:00:00.000Z',
      'opened': true,
      'openedAt': null,
      'viaLink': false,
      'groupId': null,
    }).toDomain();
    expect(x.tag, isNull);
  });

  test('오류 형식 {code, message, …추가 필드}', () {
    final e = ApiException.fromJson(402, {
      'code': 'INSUFFICIENT_CREDITS',
      'message': '크레딧이 부족해요',
      'need': 20,
    });
    expect(e.code, 'INSUFFICIENT_CREDITS');
    expect(e.extra, {'need': 20});
  });

  test('PUT /shelf/items/{id}/memo 본문: 지우기는 null', () {
    expect(const SetMemoRequest('생일').toJson(), {'memo': '생일'});
    expect(const SetMemoRequest(null).toJson(), {'memo': null});
  });

  test('PATCH /shelf/items 본문은 null도 보낸다', () {
    expect(const MoveShelfItemRequest(groupId: null, afterId: null).toJson(), {
      'groupId': null,
      'afterId': null,
    });
  });

  test('POST /billing/iap 응답: 같은 결제를 다시 보내면 alreadyProcessed', () {
    final r = IapResultDto.fromJson({
      'credits': 220,
      'granted': 0,
      'alreadyProcessed': true,
    });
    expect(r.alreadyProcessed, isTrue);
    expect(r.entry, isNull);
  });

  test('GET /shop/products (§14)', () {
    final c = ProductsDto.fromJson({
      'tapes': [
        {
          'id': 'tape60_1',
          'tapeType': 60,
          'qty': 1,
          'name': '1분 테이프',
          'price': 30,
        },
      ],
      'drawer': [
        {'id': 'drawer_10', 'name': '서랍 넓히기', 'slots': 10, 'price': 100},
      ],
      'creditPacks': [
        {
          'productId': 'tapeletter.credits_100',
          'credits': 100,
          'priceKrw': 1100,
          'priceLabel': '₩1,100',
        },
      ],
      'giftAmounts': [10, 30, 50, 100],
    }).toDomain();
    expect(c.tapes.single.type, TapeType.m1);
    expect(c.drawer.single.slots, 10);
    expect(c.packs.single.priceLabel, '₩1,100');
  });

  test('POST /dev/credits 본문', () {
    expect(const DevCreditsRequest.ad().toJson(), {'type': 'ad'});
    expect(const DevCreditsRequest.charge('tapeletter.credits_100').toJson(), {
      'type': 'charge',
      'productId': 'tapeletter.credits_100',
    });
  });

  test('IAP store 값: iOS app_store, Android play (서버 IAP_STORES)', () {
    expect(IapReceipt.storeFor(isIOS: true), 'app_store');
    expect(IapReceipt.storeFor(isIOS: false), 'play');
    expect(
      IapRequest(
        store: IapReceipt.storeFor(isIOS: false),
        productId: 'tapeletter.credits_100',
        verificationData: 'token',
      ).toJson()['store'],
      'play',
    );
  });

  group('4단계 계약', () {
    const me = {
      'id': 'u1',
      'name': null,
      'credits': 10,
      'drawer': {'stored': 0, 'cap': 12, 'full': false},
      'tapes': [
        {'tapeType': 15, 'qty': null},
      ],
      'stats': {'receivedCount': 0, 'sentCount': 0, 'friendCount': 0},
      'providers': ['kakao'],
      'notificationsEnabled': true,
      'createdAt': '2026-09-01T00:00:00.000Z',
    };

    test('AuthResponse (§6) — 토큰이 맨 위에 펼쳐져 있다', () {
      final r = AuthResponseDto.fromJson({
        'accessToken': 'eyJ',
        'accessTokenExpiresAt': '2026-09-25T07:34:46.490Z',
        'refreshToken': 'ujlq',
        'refreshTokenExpiresAt': '2026-11-24T06:34:46.490Z',
        'isNewUser': true,
        'suggestedName': '민경',
        'user': me,
      });
      expect(r.tokens.accessToken, 'eyJ');
      expect(r.tokens.refreshToken, 'ujlq');
      expect(r.isNewUser, isTrue);
      expect(r.suggestedName, '민경');
      expect(r.user.name, isNull);
    });

    test('POST /auth/apple 본문 — authorizationCode·nonce', () {
      expect(
        const AppleAuthRequest(
          identityToken: 'eyJ',
          authorizationCode: 'c1a',
          nonce: 'n',
        ).toJson(),
        {'identityToken': 'eyJ', 'authorizationCode': 'c1a', 'nonce': 'n'},
      );
    });

    test('GET /app-version (§5) — version 없으면 null', () {
      final v = AppVersionDto.fromJson({
        'platform': 'ios',
        'minVersion': '1.0.0',
        'latestVersion': '1.2.0',
        'storeUrl': 'https://apps.apple.com/app/id0000000000',
        'updateRequired': null,
        'updateAvailable': null,
      });
      expect(v.updateRequired, isNull);
      expect(v.storeUrl, startsWith('https://apps.apple.com'));
    });

    test('GET /share/{token} (§12)', () {
      final s = ShareInfoDto.fromJson({
        'state': 'available',
        'deliveryId': null,
        'sender': {'userId': 'u2', 'name': '하늘'},
        'tapeType': 15,
        'durationMs': 34000,
        'tag': 'thinking',
        'sentAt': '2026-09-25T00:00:00.000Z',
        'expiresAt': '2026-10-02T00:00:00.000Z',
      });
      expect(s.state, 'available');
      expect(s.sender.name, '하늘');
    });

    test('POST /share/{token}/claim (§12) — friend는 null일 수 있다', () {
      final c = ClaimResultDto.fromJson({
        'item': {
          'id': 't1',
          'sender': {'userId': 'u2', 'name': '하늘'},
          'tapeType': 15,
          'durationMs': 34000,
          'tag': null,
          'sentAt': '2026-09-25T00:00:00.000Z',
          'opened': false,
          'viaLink': true,
        },
        'friend': null,
      });
      expect(c.item.viaLink, isTrue);
      expect(c.friend, isNull);
    });

    test('REJOIN_RESTRICTED (§3) — availableAt', () {
      final e = ApiException.fromJson(403, {
        'code': 'REJOIN_RESTRICTED',
        'message': '탈퇴 후 30일 동안은 다시 가입할 수 없어요',
        'availableAt': '2026-10-25T12:00:00.000Z',
      });
      expect(e.code, ApiErrorCode.rejoinRestricted);
      expect(e.extra['availableAt'], '2026-10-25T12:00:00.000Z');
    });
  });

  group('별명 (nickname)', () {
    test('Friend·BlockedUser·ShelfItem.sender·SentTape.recipient — 화면에는 nickname ?? name', () {
      final f = FriendDto.fromJson({
        'userId': 'u1',
        'name': '고동민',
        'nickname': '동민이',
        'starred': true,
        'lastAt': null,
      });
      expect(f.toDomain().name, '동민이');
      final plain = FriendDto.fromJson({
        'userId': 'u2',
        'name': '지현',
        'starred': false,
        'lastAt': null,
      });
      expect(plain.nickname, isNull);
      expect(plain.toDomain().name, '지현');

      final b = BlockedUserDto.fromJson({
        'userId': 'u3',
        'name': '민수',
        'nickname': '민수형',
        'blockedAt': '2026-09-25T06:00:00.000Z',
      });
      expect(b.toDomain().name, '민수형');

      final item = ShelfItemDto.fromJson({
        'id': 't1',
        'sender': {'userId': 'u2', 'name': '지현', 'nickname': '우리 지현'},
        'tapeType': 60,
        'durationMs': 34000,
        'tag': null,
        'sentAt': '2026-09-24T09:00:00.000Z',
        'opened': false,
        'openedAt': null,
        'viaLink': false,
        'groupId': null,
      });
      expect(item.toDomain().from, '우리 지현');

      final sent = SentTapeDto.fromJson({
        'id': 's1',
        'recipient': {'userId': 'u4', 'name': '엄마', 'nickname': '우리 엄마'},
        'linkName': null,
        'tapeType': 60,
        'durationMs': 95000,
        'tag': null,
        'sentAt': '2026-09-24T09:00:00.000Z',
        'status': 'opened',
        'claimedAt': null,
        'openedAt': '2026-09-24T10:00:00.000Z',
        'share': null,
      });
      expect(sent.toDomain().to, '우리 엄마');
    });
  });

  group('새 친구 이름 (linkName 선택)', () {
    test('POST /deliveries: 비우면 linkName을 보내지 않는다, 친구에게는 linkName 없음', () {
      expect(const CreateDeliveryRequest(recordingId: 'r1').toJson(), {
        'recordingId': 'r1',
      });
      expect(
        const CreateDeliveryRequest(recordingId: 'r1', linkName: '유진').toJson(),
        {'recordingId': 'r1', 'linkName': '유진'},
      );
      expect(
        const CreateDeliveryRequest(
          recordingId: 'r1',
          recipientId: 'u1',
        ).toJson(),
        {'recordingId': 'r1', 'recipientId': 'u1'},
      );
    });

    test('SentTape 이름: nickname → name → linkName → "새 친구"', () {
      SentTapeDto sent({Map<String, Object?>? recipient, String? linkName}) =>
          SentTapeDto.fromJson({
            'id': 's1',
            'recipient': recipient,
            'linkName': linkName,
            'tapeType': 15,
            'durationMs': 20000,
            'tag': null,
            'sentAt': '2026-09-24T09:00:00.000Z',
            'status': recipient == null ? 'link_pending' : 'opened',
            'claimedAt': null,
            'openedAt': null,
            'share': recipient == null
                ? {
                    'url': 'https://tapeletter.lab241.com/t/x',
                    'expiresAt': '2026-10-01T09:00:00.000Z',
                  }
                : null,
          });
      expect(
        sent(
          recipient: {'userId': 'u', 'name': '엄마', 'nickname': '우리 엄마'},
          linkName: '엄마님',
        ).toDomain().to,
        '우리 엄마',
      );
      expect(
        sent(
          recipient: {'userId': 'u', 'name': '엄마'},
          linkName: '엄마님',
        ).toDomain().to,
        '엄마',
      );
      expect(sent(linkName: '유진').toDomain().to, '유진');
      final unnamed = sent().toDomain();
      expect(unnamed.to, '새 친구');
      expect(unnamed.link, isTrue);
    });
  });
}
