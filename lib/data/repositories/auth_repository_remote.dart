import '../../utils/format.dart';
import '../../utils/result.dart';
import '../model/api_error.dart';
import '../model/auth_dto.dart';
import '../model/me_dto.dart';
import '../services/api/api_client.dart';
import '../services/api/token_store.dart';
import '../services/audio_cache.dart';
import '../services/push_service.dart';
import '../services/social_auth_service.dart';
import 'auth_repository.dart';
import 'repository_guard.dart';

class AuthRepositoryRemote extends AuthRepository {
  AuthRepositoryRemote({
    required this._api,
    required this._tokens,
    required this._social,
    required this._push,
    this._audioCache,
  });

  final ApiClient _api;
  final TokenStore _tokens;
  final SocialAuthService _social;
  final PushService _push;

  /// 로그아웃·탈퇴하면 받은 테이프 파일도 지운다 (다른 계정이 쓸 수 있는 기기).
  final AudioCache? _audioCache;

  AuthStatus _status = AuthStatus.unknown;
  String? _suggested;

  @override
  AuthStatus get status => _status;

  @override
  String? get suggestedName => _suggested;

  void _set(AuthStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  @override
  Future<void> restore() async {
    if (await _tokens.read() == null) return _set(AuthStatus.signedOut);
    try {
      final me = await _api.getMe();
      _set(me.name == null ? AuthStatus.needsName : AuthStatus.signedIn);
    } on ApiException catch (e) {
      // 오프라인·서버 오류면 세션을 유지한다 (배너·서버 오류 화면이 알린다).
      if (e.isNetwork || e.isServerError) return _set(AuthStatus.signedIn);
      await signedOutByServer();
    }
  }

  Future<SignInResult> _complete(
    Future<AuthResponseDto> Function() call, {
    String? fallbackName,
  }) async {
    try {
      final r = await call();
      await _tokens.write(
        AuthTokens(
          access: r.tokens.accessToken,
          refresh: r.tokens.refreshToken,
        ),
      );
      _suggested = r.suggestedName ?? fallbackName;
      _set(_statusOf(r.user));
      return SignedIn(isNewUser: r.isNewUser);
    } on ApiException catch (e) {
      return SignInFailed(messageOf(e));
    }
  }

  /// 로그인 실패 토스트 문구. 탈퇴 후 재가입 제한(`403 REJOIN_RESTRICTED`)이면
  /// 서버 문구에 가능한 날짜를 붙인다 — "… · 10.25부터 가능해요".
  static String messageOf(ApiException e) {
    if (e.code == ApiErrorCode.rejoinRestricted) {
      final at = DateTime.tryParse('${e.extra['availableAt']}')?.toLocal();
      if (at != null) return '${e.message} · ${formatMonthDay(at)}부터 가능해요';
    }
    return e.message;
  }

  static AuthStatus _statusOf(MeDto me) =>
      me.name == null ? AuthStatus.needsName : AuthStatus.signedIn;

  SignInResult? _early(SocialLogin s) => switch (s) {
    SocialCanceled() => const SignInCanceled(),
    SocialUnavailable(:final message) => SignInFailed(message),
    SocialFailed() => const SignInFailed('로그인하지 못했어요. 다시 시도해 주세요'),
    _ => null,
  };

  @override
  Future<SignInResult> signInKakao() async {
    final s = await _social.kakao();
    if (_early(s) case final r?) return r;
    return _complete(() => _api.authKakao((s as KakaoLogin).accessToken));
  }

  @override
  Future<SignInResult> signInApple() async {
    final s = await _social.apple();
    if (_early(s) case final r?) return r;
    final a = s as AppleLogin;
    return _complete(
      () => _api.authApple(
        AppleAuthRequest(
          identityToken: a.identityToken,
          authorizationCode: a.authorizationCode,
          nonce: a.nonce,
        ),
      ),
      fallbackName: a.givenName,
    );
  }

  @override
  Future<SignInResult> signInGoogle() async {
    final s = await _social.google();
    if (_early(s) case final r?) return r;
    return _complete(() => _api.authGoogle((s as GoogleLogin).idToken));
  }

  @override
  Future<SignInResult> signInDev({required String key, String? name}) =>
      _complete(() => _api.authDev(key: key, name: name));

  @override
  Future<Result<void>> setName(String name) async {
    final r = await guard(
      () => _api.patchMe(PatchMeRequest(name: name.trim())),
    );
    if (r is Ok) _set(AuthStatus.signedIn);
    return r;
  }

  @override
  Future<void> logout() async {
    final t = await _tokens.read();
    try {
      final device = await _push.token();
      if (device != null) await _api.unregisterDevice(device);
    } on Exception catch (_) {}
    try {
      if (t != null) await _api.logout(t.refresh);
    } on Exception catch (_) {}
    await signedOutByServer();
  }

  @override
  Future<void> signedOutByServer() async {
    await _tokens.clear();
    _api.accessToken = null;
    await _audioCache?.clear().catchError((_) {});
    _suggested = null;
    _set(AuthStatus.signedOut);
  }
}
