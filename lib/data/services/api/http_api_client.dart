import 'dart:async';

import 'package:dio/dio.dart';

import '../../model/api_error.dart';
import '../../model/auth_dto.dart';
import '../../model/delivery_dto.dart';
import '../../model/friend_dto.dart';
import '../../model/json.dart';
import '../../model/me_dto.dart';
import '../../model/page_dto.dart';
import '../../model/recording_dto.dart';
import '../../model/report_dto.dart';
import '../../model/shelf_dto.dart';
import '../../model/shop_dto.dart';
import '../../model/wallet_dto.dart';
import 'api_client.dart';

/// 실제 서버 (`tapeletter-api`) — 계약서 `docs/api.md`와 1:1.
///
/// - 기본 주소: `--dart-define=API_BASE_URL=http://localhost:3000/api`
/// - 오류 본문 `{ code, message, …extra }` → [ApiException]
/// - 연결 실패·타임아웃 → [ApiException.network] (오프라인 배너)
/// - 🔑 요청은 `Idempotency-Key` 헤더. `409 IDEMPOTENCY_IN_PROGRESS`면 같은 키로 잠시 뒤 다시 보낸다.
class HttpApiClient implements ApiClient {
  HttpApiClient({
    required String baseUrl,
    Dio? dio,
    Duration timeout = const Duration(seconds: 15),
    this.inProgressRetryDelay = const Duration(milliseconds: 600),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: timeout,
               sendTimeout: timeout,
               receiveTimeout: timeout,
             ),
           ) {
    _dio.options
      ..baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json;
  }

  final Dio _dio;

  /// `IDEMPOTENCY_IN_PROGRESS`일 때 다시 보내기 전 기다림
  final Duration inProgressRetryDelay;

  /// 처리 중인 첫 요청을 기다리는 횟수
  static const inProgressRetries = 3;

  @override
  String? accessToken;

  // ── 전송 ─────────────────────────────────────────
  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    String? idempotencyKey,
    bool auth = true,
  }) async {
    final token = accessToken;
    final options = Options(
      method: method,
      headers: {
        if (auth && token != null) 'Authorization': 'Bearer $token',
        'Idempotency-Key': ?idempotencyKey,
      },
    );
    final q = query == null
        ? null
        : {
            for (final e in query.entries)
              if (e.value != null) e.key: '${e.value}',
          };
    for (var attempt = 0; ; attempt++) {
      try {
        final r = await _dio.request<Object?>(
          path,
          data: body,
          queryParameters: q,
          options: options,
        );
        return r.data;
      } on DioException catch (e) {
        final ex = toApiException(e);
        if (ex.code == ApiErrorCode.idempotencyInProgress &&
            idempotencyKey != null &&
            attempt < inProgressRetries) {
          await Future<void>.delayed(inProgressRetryDelay);
          continue;
        }
        throw ex;
      }
    }
  }

  Future<Json> _json(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    String? idempotencyKey,
    bool auth = true,
  }) async {
    final data = await _send(
      method,
      path,
      body: body,
      query: query,
      idempotencyKey: idempotencyKey,
      auth: auth,
    );
    if (data is Map) return data.cast<String, Object?>();
    throw const ApiException(
      status: 502,
      code: ApiErrorCode.internalError,
      message: '잠시 문제가 생겼어요. 다시 시도해 주세요',
    );
  }

  /// dio 오류 → [ApiException]. 본문이 계약서 오류 모양이 아니면 상태 코드로 만든다.
  static ApiException toApiException(DioException e) {
    final res = e.response;
    if (res == null) {
      // 연결 실패·타임아웃·취소 → 오프라인
      return ApiException.network();
    }
    final status = res.statusCode ?? 0;
    final data = res.data;
    if (data is Map && data['code'] is String && data['message'] is String) {
      return ApiException.fromJson(status, data.cast<String, Object?>());
    }
    return ApiException(
      status: status,
      code: status >= 500 ? ApiErrorCode.internalError : 'HTTP_$status',
      message: '잠시 문제가 생겼어요. 다시 시도해 주세요',
    );
  }

  static String _seg(String s) => Uri.encodeComponent(s);

  // ── 공개 ─────────────────────────────────────────
  @override
  Future<void> health() => _send('GET', '/health', auth: false);

  @override
  Future<AppVersionDto> getAppVersion({
    required String platform,
    String? version,
  }) async => AppVersionDto.fromJson(
    await _json(
      'GET',
      '/app-version',
      query: {'platform': platform, 'version': version},
      auth: false,
    ),
  );

  @override
  Future<AuthResponseDto> authKakao(String kakaoAccessToken) async =>
      AuthResponseDto.fromJson(
        await _json(
          'POST',
          '/auth/kakao',
          body: {'accessToken': kakaoAccessToken},
          auth: false,
        ),
      );

  @override
  Future<AuthResponseDto> authApple(AppleAuthRequest body) async =>
      AuthResponseDto.fromJson(
        await _json('POST', '/auth/apple', body: body.toJson(), auth: false),
      );

  @override
  Future<AuthResponseDto> authDev({required String key, String? name}) async =>
      AuthResponseDto.fromJson(
        await _json(
          'POST',
          '/auth/dev',
          body: {'key': key, 'name': ?name},
          auth: false,
        ),
      );

  @override
  Future<TokenPairDto> refreshTokens(String refreshToken) async =>
      TokenPairDto.fromJson(
        await _json(
          'POST',
          '/auth/refresh',
          body: {'refreshToken': refreshToken},
          auth: false,
        ),
      );

  @override
  Future<void> logout(String refreshToken) => _send(
    'POST',
    '/auth/logout',
    body: {'refreshToken': refreshToken},
    auth: false,
  );

  // ── notifications ─────────────────────────────────
  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) => _send(
    'PUT',
    '/notifications/devices',
    body: {'token': token, 'platform': platform},
  );

  @override
  Future<void> unregisterDevice(String token) =>
      _send('DELETE', '/notifications/devices/${_seg(token)}');

  // ── share ─────────────────────────────────────────
  @override
  Future<ShareInfoDto> getShare(String token) async =>
      ShareInfoDto.fromJson(await _json('GET', '/share/${_seg(token)}'));

  @override
  Future<ClaimResultDto> claimShare(
    String token, {
    required String idempotencyKey,
  }) async => ClaimResultDto.fromJson(
    await _json(
      'POST',
      '/share/${_seg(token)}/claim',
      idempotencyKey: idempotencyKey,
    ),
  );

  // ── users ─────────────────────────────────────────
  @override
  Future<MeDto> getMe() async =>
      MeDto.fromJson(await _json('GET', '/users/me'));

  @override
  Future<MeDto> patchMe(PatchMeRequest body) async =>
      MeDto.fromJson(await _json('PATCH', '/users/me', body: body.toJson()));

  @override
  Future<void> deleteMe() => _send('DELETE', '/users/me');

  // ── friends ───────────────────────────────────────
  @override
  Future<PageDto<FriendDto>> getFriends() async =>
      PageDto.fromJson(await _json('GET', '/friends'), FriendDto.fromJson);

  @override
  Future<FriendDto> patchFriend(String userId, {required bool starred}) async =>
      FriendDto.fromJson(
        await _json(
          'PATCH',
          '/friends/${_seg(userId)}',
          body: {'starred': starred},
        ),
      );

  @override
  Future<FriendDto> setFriendNickname(String userId, String? nickname) async =>
      FriendDto.fromJson(
        await _json(
          'PATCH',
          '/friends/${_seg(userId)}',
          body: {'nickname': nickname},
        ),
      );

  @override
  Future<FriendTapesDto> getFriendTapes(String userId) async =>
      FriendTapesDto.fromJson(
        await _json('GET', '/friends/${_seg(userId)}/tapes'),
      );

  @override
  Future<void> deleteFriend(String userId) =>
      _send('DELETE', '/friends/${_seg(userId)}');

  @override
  Future<BlockedUserDto> blockUser(String userId) async =>
      BlockedUserDto.fromJson(
        await _json('POST', '/friends/${_seg(userId)}/block'),
      );

  @override
  Future<PageDto<BlockedUserDto>> getBlocks() async => PageDto.fromJson(
    await _json('GET', '/friends/blocks'),
    BlockedUserDto.fromJson,
  );

  @override
  Future<void> unblockUser(String userId) =>
      _send('DELETE', '/friends/${_seg(userId)}/block');

  // ── recordings ────────────────────────────────────
  @override
  Future<RecordingUploadDto> createRecording(
    CreateRecordingRequest body,
  ) async => RecordingUploadDto.fromJson(
    await _json('POST', '/recordings', body: body.toJson()),
  );

  @override
  Future<RecordingDto> completeRecording(String id) async =>
      RecordingDto.fromJson(
        await _json('POST', '/recordings/${_seg(id)}/complete'),
      );

  @override
  Future<RecordingDto> getRecording(String id) async =>
      RecordingDto.fromJson(await _json('GET', '/recordings/${_seg(id)}'));

  @override
  Future<RecordingDto> retryRecording(String id) async => RecordingDto.fromJson(
    await _json('POST', '/recordings/${_seg(id)}/retry'),
  );

  // ── deliveries ────────────────────────────────────
  @override
  Future<SentTapeDto> createDelivery(
    CreateDeliveryRequest body, {
    required String idempotencyKey,
  }) async => SentTapeDto.fromJson(
    await _json(
      'POST',
      '/deliveries',
      body: body.toJson(),
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<PageDto<SentTapeDto>> getSent({String? cursor, int? limit}) async =>
      PageDto.fromJson(
        await _json(
          'GET',
          '/deliveries/sent',
          query: {'cursor': cursor, 'limit': limit},
        ),
        SentTapeDto.fromJson,
      );

  @override
  Future<SentTapeDto> getSentTape(String id) async =>
      SentTapeDto.fromJson(await _json('GET', '/deliveries/sent/${_seg(id)}'));

  @override
  Future<ShareLinkDto> reshareSent(String id) async => ShareLinkDto.fromJson(
    await _json('POST', '/deliveries/sent/${_seg(id)}/share'),
  );

  @override
  Future<ShelfItemDto> getDelivery(String id) async =>
      ShelfItemDto.fromJson(await _json('GET', '/deliveries/${_seg(id)}'));

  @override
  Future<ShelfItemDto> openDelivery(String id) async => ShelfItemDto.fromJson(
    await _json('POST', '/deliveries/${_seg(id)}/open'),
  );

  @override
  Future<AudioUrlDto> getDeliveryAudio(String id) async =>
      AudioUrlDto.fromJson(await _json('GET', '/deliveries/${_seg(id)}/audio'));

  // ── shelf ─────────────────────────────────────────
  @override
  Future<ShelfDto> getShelf() async =>
      ShelfDto.fromJson(await _json('GET', '/shelf'));

  @override
  Future<ShelfGroupDto> createGroup(String name) async =>
      ShelfGroupDto.fromJson(
        await _json('POST', '/shelf/groups', body: {'name': name}),
      );

  @override
  Future<ShelfGroupDto> renameGroup(String id, String name) async =>
      ShelfGroupDto.fromJson(
        await _json('PATCH', '/shelf/groups/${_seg(id)}', body: {'name': name}),
      );

  @override
  Future<void> deleteGroup(String id) =>
      _send('DELETE', '/shelf/groups/${_seg(id)}');

  @override
  Future<ShelfItemDto> moveShelfItem(
    String id,
    MoveShelfItemRequest body,
  ) async => ShelfItemDto.fromJson(
    await _json('PATCH', '/shelf/items/${_seg(id)}', body: body.toJson()),
  );

  @override
  Future<ShelfItemDto> setShelfItemMemo(String id, SetMemoRequest body) async =>
      ShelfItemDto.fromJson(
        await _json(
          'PUT',
          '/shelf/items/${_seg(id)}/memo',
          body: body.toJson(),
        ),
      );

  @override
  Future<void> deleteShelfItem(String id) =>
      _send('DELETE', '/shelf/items/${_seg(id)}');

  // ── wallet ────────────────────────────────────────
  @override
  Future<WalletDto> getWallet() async =>
      WalletDto.fromJson(await _json('GET', '/wallet'));

  @override
  Future<PageDto<LedgerEntryDto>> getLedger({
    String? cursor,
    int? limit,
  }) async => PageDto.fromJson(
    await _json(
      'GET',
      '/wallet/ledger',
      query: {'cursor': cursor, 'limit': limit},
    ),
    LedgerEntryDto.fromJson,
  );

  @override
  Future<GiftResultDto> sendGift({
    required String toUserId,
    required int amount,
    required String idempotencyKey,
  }) async => GiftResultDto.fromJson(
    await _json(
      'POST',
      '/wallet/gifts',
      body: {'toUserId': toUserId, 'amount': amount},
      idempotencyKey: idempotencyKey,
    ),
  );

  // ── shop · billing ────────────────────────────────
  @override
  Future<ProductsDto> getProducts() async =>
      ProductsDto.fromJson(await _json('GET', '/shop/products'));

  @override
  Future<PurchaseResultDto> purchase(
    String productId, {
    required String idempotencyKey,
  }) async => PurchaseResultDto.fromJson(
    await _json(
      'POST',
      '/shop/purchases',
      body: {'productId': productId},
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<IapResultDto> verifyIap(
    IapRequest body, {
    required String idempotencyKey,
  }) async => IapResultDto.fromJson(
    await _json(
      'POST',
      '/billing/iap',
      body: body.toJson(),
      idempotencyKey: idempotencyKey,
    ),
  );

  // ── reports ───────────────────────────────────────
  @override
  Future<ReportResultDto> createReport(
    CreateReportRequest body, {
    required String idempotencyKey,
  }) async => ReportResultDto.fromJson(
    await _json(
      'POST',
      '/reports',
      body: body.toJson(),
      idempotencyKey: idempotencyKey,
    ),
  );

  // ── dev ───────────────────────────────────────────
  @override
  Future<WalletDto> devCredits(DevCreditsRequest body) async =>
      WalletDto.fromJson(
        await _json('POST', '/dev/credits', body: body.toJson()),
      );

  @override
  Future<void> devSeed() => _send('POST', '/dev/seed');

  @override
  Future<FriendDto> devFriend({
    String? userId,
    String? name,
    bool? starred,
  }) async => FriendDto.fromJson(
    await _json(
      'POST',
      '/dev/friends',
      body: {'userId': ?userId, 'name': ?name, 'starred': ?starred},
    ),
  );
}
