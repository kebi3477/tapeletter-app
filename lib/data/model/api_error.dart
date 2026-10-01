import 'json.dart';

/// 계약서 §1 오류 형식 `{ code, message, …추가 필드 }`. 앱은 `code`로 분기한다.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.extra = const {},
  });

  factory ApiException.fromJson(int status, Json j) => ApiException(
    status: status,
    code: j['code'] as String,
    message: j['message'] as String,
    extra: {
      for (final e in j.entries)
        if (e.key != 'code' && e.key != 'message') e.key: e.value,
    },
  );

  final int status;
  final String code;
  final String message;

  /// 예: `need`, `tapeType`, `status`, `deliveryId`, `url`
  final Json extra;

  /// 요청이 서버에 닿지 않았다 (오프라인 등). HTTP 상태가 없다.
  static const networkStatus = 0;

  const ApiException.network()
    : status = networkStatus,
      code = ApiErrorCode.networkError,
      message = '인터넷에 연결되어 있지 않아요',
      extra = const {};

  bool get isNetwork => status == networkStatus;
  bool get isServerError => status >= 500;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

/// 계약서 §3 오류 코드 중 앱이 분기하는 것.
abstract final class ApiErrorCode {
  static const notFound = 'NOT_FOUND';
  static const validationFailed = 'VALIDATION_FAILED';
  static const friendNotFound = 'FRIEND_NOT_FOUND';
  static const noTapeLeft = 'NO_TAPE_LEFT';
  static const recordingNotFound = 'RECORDING_NOT_FOUND';
  static const recordingNotReady = 'RECORDING_NOT_READY';
  static const recordingTooLong = 'RECORDING_TOO_LONG';
  static const recordingAlreadySent = 'RECORDING_ALREADY_SENT';
  static const notFriend = 'NOT_FRIEND';
  static const tapeNotFound = 'TAPE_NOT_FOUND';
  static const invalidMemo = 'INVALID_MEMO';
  static const tapeNotOpened = 'TAPE_NOT_OPENED';
  static const uploadNotFound = 'UPLOAD_NOT_FOUND';
  static const recordingTooLarge = 'RECORDING_TOO_LARGE';
  static const audioNotReady = 'AUDIO_NOT_READY';
  static const groupNotFound = 'GROUP_NOT_FOUND';

  /// 서랍이 꽉 차서 소포를 뜯을 수 없다 (`POST /deliveries/{id}/open` 409)
  static const drawerFull = 'DRAWER_FULL';

  /// 그 칸에 10개가 차 있다 (`PATCH /shelf/items/{id}` 409)
  static const groupFull = 'GROUP_FULL';
  static const invalidGroupName = 'INVALID_GROUP_NAME';
  static const internalError = 'INTERNAL_ERROR';
  static const networkError = 'NETWORK_ERROR';
  static const unauthorized = 'UNAUTHORIZED';
  static const invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  static const socialTokenInvalid = 'SOCIAL_TOKEN_INVALID';
  static const invalidName = 'INVALID_NAME';
  static const invalidNickname = 'INVALID_NICKNAME';
  static const linkNotFound = 'LINK_NOT_FOUND';
  static const linkExpired = 'LINK_EXPIRED';
  static const linkOwn = 'LINK_OWN';
  static const rejoinRestricted = 'REJOIN_RESTRICTED';
  static const insufficientCredits = 'INSUFFICIENT_CREDITS';
  static const invalidGiftAmount = 'INVALID_GIFT_AMOUNT';
  static const productNotFound = 'PRODUCT_NOT_FOUND';
  static const adLimitReached = 'AD_LIMIT_REACHED';
  static const receiptInvalid = 'RECEIPT_INVALID';
  static const receiptPending = 'RECEIPT_PENDING';
  static const receiptAlreadyUsed = 'RECEIPT_ALREADY_USED';
  static const iapUnavailable = 'IAP_UNAVAILABLE';
  static const giftNotAllowed = 'GIFT_NOT_ALLOWED';
  static const linkTaken = 'LINK_TAKEN';
  static const blockNotFound = 'BLOCK_NOT_FOUND';
  static const cannotBlockSelf = 'CANNOT_BLOCK_SELF';
  static const userNotFound = 'USER_NOT_FOUND';
  static const idempotencyInProgress = 'IDEMPOTENCY_IN_PROGRESS';
  static const idempotencyKeyReused = 'IDEMPOTENCY_KEY_REUSED';
  static const rateLimited = 'RATE_LIMITED';
  static const reportTargetNotFound = 'REPORT_TARGET_NOT_FOUND';
  static const cannotReportSelf = 'CANNOT_REPORT_SELF';

  /// 저장소 PUT 실패 (앱이 만든 코드. 서버 오류 코드가 아니다)
  static const uploadFailed = 'UPLOAD_FAILED';
}
