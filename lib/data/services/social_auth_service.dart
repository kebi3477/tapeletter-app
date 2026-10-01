import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 소셜 로그인 결과
sealed class SocialLogin {
  const SocialLogin();
}

/// 카카오 액세스 토큰 → `POST /auth/kakao`
class KakaoLogin extends SocialLogin {
  const KakaoLogin(this.accessToken);

  final String accessToken;
}

/// Apple → `POST /auth/apple` (`authorizationCode`도 보낸다)
class AppleLogin extends SocialLogin {
  const AppleLogin({
    required this.identityToken,
    required this.authorizationCode,
    this.nonce,
    this.givenName,
  });

  final String identityToken;
  final String authorizationCode;
  final String? nonce;

  /// 첫 로그인 때만 온다 — 이름 정하기 화면에 미리 채운다.
  final String? givenName;
}

/// Google ID 토큰 → `POST /auth/google` (Android 전용)
class GoogleLogin extends SocialLogin {
  const GoogleLogin(this.idToken);

  final String idToken;
}

/// 사용자가 창을 닫았다
class SocialCanceled extends SocialLogin {
  const SocialCanceled();
}

/// 설정이 없어 쓸 수 없다 (예: 카카오 네이티브 앱 키 없음)
class SocialUnavailable extends SocialLogin {
  const SocialUnavailable(this.message);

  final String message;
}

class SocialFailed extends SocialLogin {
  const SocialFailed([this.message]);

  final String? message;
}

/// 카카오·Apple(iOS)·Google(Android) 로그인 SDK.
abstract class SocialAuthService {
  Future<SocialLogin> kakao();

  Future<SocialLogin> apple();

  Future<SocialLogin> google();
}

/// `kakao_flutter_sdk_user` + `sign_in_with_apple` + `google_sign_in`.
class PlatformSocialAuthService implements SocialAuthService {
  PlatformSocialAuthService({
    required this.kakaoNativeAppKey,
    required this.googleServerClientId,
  });

  final String kakaoNativeAppKey;

  /// Google Cloud **웹** OAuth 클라이언트 ID (`GOOGLE_SERVER_CLIENT_ID`).
  /// ID 토큰의 `aud`가 이 값이 되고, 서버가 이 값으로 토큰을 확인한다.
  final String googleServerClientId;
  bool _kakaoReady = false;
  Future<void>? _googleReady;

  static const kakaoKeyMissing = '카카오 앱 키가 설정되지 않았어요';

  @override
  Future<SocialLogin> kakao() async {
    if (kakaoNativeAppKey.isEmpty) {
      return const SocialUnavailable(kakaoKeyMissing);
    }
    try {
      if (!_kakaoReady) {
        await KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
        _kakaoReady = true;
      }
      final token = await isKakaoTalkInstalled()
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();
      return KakaoLogin(token.accessToken);
    } on KakaoAuthException catch (e) {
      return e.error == AuthErrorCause.accessDenied
          ? const SocialCanceled()
          : SocialFailed(e.message);
    } on KakaoClientException catch (e) {
      return e.reason == ClientErrorCause.cancelled
          ? const SocialCanceled()
          : SocialFailed(e.msg);
    } catch (e) {
      return SocialFailed('$e');
    }
  }

  @override
  Future<SocialLogin> apple() async {
    final nonce = _nonce();
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
      );
      final idToken = c.identityToken;
      if (idToken == null) return const SocialFailed();
      return AppleLogin(
        identityToken: idToken,
        authorizationCode: c.authorizationCode,
        nonce: nonce,
        givenName: c.givenName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      return e.code == AuthorizationErrorCode.canceled
          ? const SocialCanceled()
          : SocialFailed(e.message);
    } catch (e) {
      return SocialFailed('$e');
    }
  }

  @override
  Future<SocialLogin> google() async {
    if (googleServerClientId.isEmpty) {
      // 설정이 없으면 일반 로그인 실패 토스트로 알린다 (docs/SETUP.md).
      debugPrint('google sign-in: GOOGLE_SERVER_CLIENT_ID가 비어 있다');
      return const SocialFailed('GOOGLE_SERVER_CLIENT_ID missing');
    }
    try {
      final g = GoogleSignIn.instance;
      await (_googleReady ??= g.initialize(
        serverClientId: googleServerClientId,
      ));
      final account = await g.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return const SocialFailed();
      return GoogleLogin(idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const SocialCanceled();
      }
      debugPrint('google sign-in: $e');
      return SocialFailed(e.description);
    } catch (e) {
      debugPrint('google sign-in: $e');
      return SocialFailed('$e');
    }
  }

  static String _nonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
