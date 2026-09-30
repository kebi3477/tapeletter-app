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

/// 서버 API — `tapeletter-api/docs/api.md`의 엔드포인트와 1:1.
///
/// 실패하면 [ApiException](../../model/api_error.dart)을 던진다.
/// 구현: [HttpApiClient](실제 서버), [LocalApiClient](서버 없이 도는 메모리 가짜).
abstract class ApiClient {
  /// 보호된 API에 붙일 `Authorization: Bearer` 값. [AuthorizedApiClient]가 채운다.
  String? accessToken;

  // 공개 (@공개)
  /// `GET /health`
  Future<void> health();

  /// `GET /app-version?platform=&version=`
  Future<AppVersionDto> getAppVersion({
    required String platform,
    String? version,
  });

  /// `POST /auth/kakao` `{ accessToken }`
  Future<AuthResponseDto> authKakao(String kakaoAccessToken);

  /// `POST /auth/apple`
  Future<AuthResponseDto> authApple(AppleAuthRequest body);

  /// `POST /auth/dev` `{ key, name? }` — 개발 전용
  Future<AuthResponseDto> authDev({required String key, String? name});

  /// `POST /auth/refresh` — refresh token은 한 번 쓰면 사라진다(회전).
  Future<TokenPairDto> refreshTokens(String refreshToken);

  /// `POST /auth/logout`
  Future<void> logout(String refreshToken);

  // notifications
  /// `PUT /notifications/devices` `{ token, platform }`
  Future<void> registerDevice({
    required String token,
    required String platform,
  });

  /// `DELETE /notifications/devices/{token}`
  Future<void> unregisterDevice(String token);

  // share
  /// `GET /share/{token}`
  Future<ShareInfoDto> getShare(String token);

  /// `POST /share/{token}/claim` 🔑
  Future<ClaimResultDto> claimShare(
    String token, {
    required String idempotencyKey,
  });

  // users
  /// `GET /users/me`
  Future<MeDto> getMe();

  /// `PATCH /users/me`
  Future<MeDto> patchMe(PatchMeRequest body);

  /// `DELETE /users/me` — 회원 탈퇴
  Future<void> deleteMe();

  // friends
  /// `GET /friends`
  Future<PageDto<FriendDto>> getFriends();

  /// `PATCH /friends/{userId}` `{ starred }`
  Future<FriendDto> patchFriend(String userId, {required bool starred});

  /// `PATCH /friends/{userId}` `{ nickname }` — 별명(최대 10자). null·빈 값이면 지운다.
  Future<FriendDto> setFriendNickname(String userId, String? nickname);

  /// `GET /friends/{userId}/tapes`
  Future<FriendTapesDto> getFriendTapes(String userId);

  /// `DELETE /friends/{userId}` — 목록에서 빼기
  Future<void> deleteFriend(String userId);

  /// `POST /friends/{userId}/block`
  Future<BlockedUserDto> blockUser(String userId);

  /// `GET /friends/blocks`
  Future<PageDto<BlockedUserDto>> getBlocks();

  /// `DELETE /friends/{userId}/block`
  Future<void> unblockUser(String userId);

  // recordings
  /// `POST /recordings`
  Future<RecordingUploadDto> createRecording(CreateRecordingRequest body);

  /// `POST /recordings/{id}/complete`
  Future<RecordingDto> completeRecording(String id);

  /// `GET /recordings/{id}`
  Future<RecordingDto> getRecording(String id);

  /// `POST /recordings/{id}/retry`
  Future<RecordingDto> retryRecording(String id);

  // deliveries
  /// `POST /deliveries` 🔑
  Future<SentTapeDto> createDelivery(
    CreateDeliveryRequest body, {
    required String idempotencyKey,
  });

  /// `GET /deliveries/sent`
  Future<PageDto<SentTapeDto>> getSent({String? cursor, int? limit});

  /// `GET /deliveries/sent/{id}` — 보낸 테이프 상세
  Future<SentTapeDto> getSentTape(String id);

  /// `POST /deliveries/sent/{id}/share` — 링크 다시 공유하기
  Future<ShareLinkDto> reshareSent(String id);

  /// `GET /deliveries/{id}`
  Future<ShelfItemDto> getDelivery(String id);

  /// `POST /deliveries/{id}/open`
  Future<ShelfItemDto> openDelivery(String id);

  /// `GET /deliveries/{id}/audio`
  Future<AudioUrlDto> getDeliveryAudio(String id);

  // shelf
  /// `GET /shelf`
  Future<ShelfDto> getShelf();

  /// `POST /shelf/groups` `{ name }`
  Future<ShelfGroupDto> createGroup(String name);

  /// `PATCH /shelf/groups/{id}` `{ name }`
  Future<ShelfGroupDto> renameGroup(String id, String name);

  /// `DELETE /shelf/groups/{id}`
  Future<void> deleteGroup(String id);

  /// `PATCH /shelf/items/{id}` `{ groupId, afterId }`
  Future<ShelfItemDto> moveShelfItem(String id, MoveShelfItemRequest body);

  /// `PUT /shelf/items/{id}/memo` `{ memo }` — 메모(최대 40자). null·빈 값이면 지운다.
  Future<ShelfItemDto> setShelfItemMemo(String id, SetMemoRequest body);

  /// `DELETE /shelf/items/{id}`
  Future<void> deleteShelfItem(String id);

  // wallet
  /// `GET /wallet`
  Future<WalletDto> getWallet();

  /// `GET /wallet/ledger`
  Future<PageDto<LedgerEntryDto>> getLedger({String? cursor, int? limit});

  /// `POST /wallet/gifts` 🔑
  Future<GiftResultDto> sendGift({
    required String toUserId,
    required int amount,
    required String idempotencyKey,
  });

  // shop · billing
  /// `GET /shop/products`
  Future<ProductsDto> getProducts();

  /// `POST /shop/purchases` 🔑
  Future<PurchaseResultDto> purchase(
    String productId, {
    required String idempotencyKey,
  });

  /// `POST /billing/iap` 🔑
  Future<IapResultDto> verifyIap(
    IapRequest body, {
    required String idempotencyKey,
  });

  // reports
  /// `POST /reports` 🔑 — 신고 (테이프·사람), `alsoBlock`이면 같이 차단
  Future<ReportResultDto> createReport(
    CreateReportRequest body, {
    required String idempotencyKey,
  });

  // dev (운영 404)
  /// `POST /dev/credits` — 스토어·AdMob 없이 광고 보상·충전을 흉내 낸다. 응답은 `GET /wallet`과 같다.
  Future<WalletDto> devCredits(DevCreditsRequest body);

  /// `POST /dev/seed` — 로그인한 계정을 프로토타입 초기 데이터로 (통합 테스트·개발 로그인)
  Future<void> devSeed();

  /// `POST /dev/friends` `{ userId }` 또는 `{ name, starred? }` — 서로 친구
  Future<FriendDto> devFriend({String? userId, String? name, bool? starred});
}
