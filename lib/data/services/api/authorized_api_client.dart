import 'dart:async';

import '../../model/api_error.dart';
import '../../model/auth_dto.dart';
import '../../model/delivery_dto.dart';
import '../../model/friend_dto.dart';
import '../../model/me_dto.dart';
import '../../model/page_dto.dart';
import '../../model/recording_dto.dart';
import '../../model/report_dto.dart';
import '../../model/shelf_dto.dart';
import '../../model/shop_dto.dart';
import '../../model/wallet_dto.dart';
import 'api_client.dart';
import 'api_status.dart';
import 'token_store.dart';

/// 모든 요청에 access token을 붙이고, `401`이면 refresh 후 한 번 다시 보낸다 (계약서 §1 인증 흐름).
///
/// - 동시에 여러 요청이 401을 받아도 refresh는 한 번만 부른다(단일 비행).
/// - refresh token은 회전한다 — 새로 받은 값으로 바꿔 저장한다.
/// - refresh도 실패하면 토큰을 지우고 [onSessionExpired]를 부른다 → 로그인 화면.
/// - 네트워크 실패와 5xx는 [ApiStatus]에 알린다 (오프라인 배너, 서버 오류 화면).
///
/// 아래 메서드는 [ApiClient] 선언을 그대로 옮겨 공개/보호 여부만 나눈 것이다.
class AuthorizedApiClient implements ApiClient {
  AuthorizedApiClient(this._inner, this._tokens, this._status);

  final ApiClient _inner;
  final TokenStore _tokens;
  final ApiStatus _status;

  /// refresh가 실패해 다시 로그인해야 할 때
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  @override
  String? get accessToken => _inner.accessToken;

  @override
  set accessToken(String? v) => _inner.accessToken = v;

  Future<T> _public<T>(Future<T> Function() call) => _report(call);

  Future<T> _protected<T>(Future<T> Function() call) async {
    final t = await _tokens.read();
    _inner.accessToken = t?.access;
    try {
      return await _report(call);
    } on ApiException catch (e) {
      if (!e.isUnauthorized || t == null) rethrow;
      if (!await _refresh(t)) rethrow;
      _inner.accessToken = (await _tokens.read())?.access;
      return _report(call);
    }
  }

  Future<T> _report<T>(Future<T> Function() call) async {
    try {
      final r = await call();
      _status.reportOk();
      return r;
    } on ApiException catch (e) {
      if (e.isNetwork) _status.reportNetworkFailure();
      if (e.isServerError) _status.reportServerError();
      rethrow;
    }
  }

  /// 단일 비행 refresh. 성공하면 true.
  Future<bool> _refresh(AuthTokens stale) {
    return _refreshing ??= () async {
      try {
        // 다른 요청이 이미 새 토큰을 받아 두었으면 그걸 쓴다.
        final now = await _tokens.read();
        if (now != null && now.access != stale.access) return true;
        final pair = await _inner.refreshTokens(stale.refresh);
        await _tokens.write(
          AuthTokens(access: pair.accessToken, refresh: pair.refreshToken),
        );
        return true;
      } on ApiException catch (e) {
        if (e.isNetwork || e.isServerError) return false;
        await _tokens.clear();
        onSessionExpired?.call();
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  @override
  Future<void> health() => _public(() => _inner.health());

  @override
  Future<AppVersionDto> getAppVersion({
    required String platform,
    String? version,
  }) =>
      _public(() => _inner.getAppVersion(platform: platform, version: version));

  @override
  Future<AuthResponseDto> authKakao(String kakaoAccessToken) =>
      _public(() => _inner.authKakao(kakaoAccessToken));

  @override
  Future<AuthResponseDto> authApple(AppleAuthRequest body) =>
      _public(() => _inner.authApple(body));

  @override
  Future<AuthResponseDto> authDev({required String key, String? name}) =>
      _public(() => _inner.authDev(key: key, name: name));

  @override
  Future<TokenPairDto> refreshTokens(String refreshToken) =>
      _public(() => _inner.refreshTokens(refreshToken));

  @override
  Future<void> logout(String refreshToken) =>
      _public(() => _inner.logout(refreshToken));

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) =>
      _protected(() => _inner.registerDevice(token: token, platform: platform));

  @override
  Future<void> unregisterDevice(String token) =>
      _protected(() => _inner.unregisterDevice(token));

  @override
  Future<ShareInfoDto> getShare(String token) =>
      _protected(() => _inner.getShare(token));

  @override
  Future<ClaimResultDto> claimShare(
    String token, {
    required String idempotencyKey,
  }) => _protected(
    () => _inner.claimShare(token, idempotencyKey: idempotencyKey),
  );

  @override
  Future<MeDto> getMe() => _protected(() => _inner.getMe());

  @override
  Future<MeDto> patchMe(PatchMeRequest body) =>
      _protected(() => _inner.patchMe(body));

  @override
  Future<void> deleteMe() => _protected(() => _inner.deleteMe());

  @override
  Future<PageDto<FriendDto>> getFriends() =>
      _protected(() => _inner.getFriends());

  @override
  Future<FriendDto> patchFriend(String userId, {required bool starred}) =>
      _protected(() => _inner.patchFriend(userId, starred: starred));

  @override
  Future<FriendDto> setFriendNickname(String userId, String? nickname) =>
      _protected(() => _inner.setFriendNickname(userId, nickname));

  @override
  Future<FriendTapesDto> getFriendTapes(String userId) =>
      _protected(() => _inner.getFriendTapes(userId));

  @override
  Future<void> deleteFriend(String userId) =>
      _protected(() => _inner.deleteFriend(userId));

  @override
  Future<BlockedUserDto> blockUser(String userId) =>
      _protected(() => _inner.blockUser(userId));

  @override
  Future<PageDto<BlockedUserDto>> getBlocks() =>
      _protected(() => _inner.getBlocks());

  @override
  Future<void> unblockUser(String userId) =>
      _protected(() => _inner.unblockUser(userId));

  @override
  Future<RecordingUploadDto> createRecording(CreateRecordingRequest body) =>
      _protected(() => _inner.createRecording(body));

  @override
  Future<RecordingDto> completeRecording(String id) =>
      _protected(() => _inner.completeRecording(id));

  @override
  Future<RecordingDto> getRecording(String id) =>
      _protected(() => _inner.getRecording(id));

  @override
  Future<RecordingDto> retryRecording(String id) =>
      _protected(() => _inner.retryRecording(id));

  @override
  Future<SentTapeDto> createDelivery(
    CreateDeliveryRequest body, {
    required String idempotencyKey,
  }) => _protected(
    () => _inner.createDelivery(body, idempotencyKey: idempotencyKey),
  );

  @override
  Future<PageDto<SentTapeDto>> getSent({String? cursor, int? limit}) =>
      _protected(() => _inner.getSent(cursor: cursor, limit: limit));

  @override
  Future<SentTapeDto> getSentTape(String id) =>
      _protected(() => _inner.getSentTape(id));

  @override
  Future<ShareLinkDto> reshareSent(String id) =>
      _protected(() => _inner.reshareSent(id));

  @override
  Future<ShelfItemDto> getDelivery(String id) =>
      _protected(() => _inner.getDelivery(id));

  @override
  Future<ShelfItemDto> openDelivery(String id) =>
      _protected(() => _inner.openDelivery(id));

  @override
  Future<AudioUrlDto> getDeliveryAudio(String id) =>
      _protected(() => _inner.getDeliveryAudio(id));

  @override
  Future<ShelfDto> getShelf() => _protected(() => _inner.getShelf());

  @override
  Future<ShelfGroupDto> createGroup(String name) =>
      _protected(() => _inner.createGroup(name));

  @override
  Future<ShelfGroupDto> renameGroup(String id, String name) =>
      _protected(() => _inner.renameGroup(id, name));

  @override
  Future<void> deleteGroup(String id) =>
      _protected(() => _inner.deleteGroup(id));

  @override
  Future<ShelfItemDto> moveShelfItem(String id, MoveShelfItemRequest body) =>
      _protected(() => _inner.moveShelfItem(id, body));

  @override
  Future<ShelfItemDto> setShelfItemMemo(String id, SetMemoRequest body) =>
      _protected(() => _inner.setShelfItemMemo(id, body));

  @override
  Future<void> deleteShelfItem(String id) =>
      _protected(() => _inner.deleteShelfItem(id));

  @override
  Future<WalletDto> getWallet() => _protected(() => _inner.getWallet());

  @override
  Future<PageDto<LedgerEntryDto>> getLedger({String? cursor, int? limit}) =>
      _protected(() => _inner.getLedger(cursor: cursor, limit: limit));

  @override
  Future<GiftResultDto> sendGift({
    required String toUserId,
    required int amount,
    required String idempotencyKey,
  }) => _protected(
    () => _inner.sendGift(
      toUserId: toUserId,
      amount: amount,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<ProductsDto> getProducts() => _protected(() => _inner.getProducts());

  @override
  Future<PurchaseResultDto> purchase(
    String productId, {
    required String idempotencyKey,
  }) => _protected(
    () => _inner.purchase(productId, idempotencyKey: idempotencyKey),
  );

  @override
  Future<IapResultDto> verifyIap(
    IapRequest body, {
    required String idempotencyKey,
  }) =>
      _protected(() => _inner.verifyIap(body, idempotencyKey: idempotencyKey));

  @override
  Future<WalletDto> devCredits(DevCreditsRequest body) =>
      _protected(() => _inner.devCredits(body));

  @override
  Future<ReportResultDto> createReport(
    CreateReportRequest body, {
    required String idempotencyKey,
  }) => _protected(
    () => _inner.createReport(body, idempotencyKey: idempotencyKey),
  );

  @override
  Future<void> devSeed() => _protected(_inner.devSeed);

  @override
  Future<FriendDto> devFriend({String? userId, String? name, bool? starred}) =>
      _protected(
        () => _inner.devFriend(userId: userId, name: name, starred: starred),
      );
}
