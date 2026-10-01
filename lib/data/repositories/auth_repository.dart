import 'package:flutter/foundation.dart';

import '../../utils/result.dart';

/// 로그인 상태
enum AuthStatus {
  /// 아직 저장된 토큰을 확인하지 않았다 (스플래시)
  unknown,

  /// 로그인 화면
  signedOut,

  /// 가입 직후 이름이 없다 → 이름 정하기 (`user.name == null`)
  needsName,
  signedIn,
}

/// 로그인 결과
sealed class SignInResult {
  const SignInResult();
}

class SignedIn extends SignInResult {
  const SignedIn({required this.isNewUser});

  final bool isNewUser;
}

/// 사용자가 로그인 창을 닫았다 — 아무 안내 없이 로그인 화면에 머문다.
class SignInCanceled extends SignInResult {
  const SignInCanceled();
}

/// 토스트로 알릴 실패 (카카오 앱 키 없음, 서버 거절 등)
class SignInFailed extends SignInResult {
  const SignInFailed(this.message);

  final String message;
}

/// 로그인·토큰 (`/auth/*`). 상태가 바뀌면 리스너(라우터)에게 알린다.
abstract class AuthRepository extends ChangeNotifier {
  AuthStatus get status;

  /// 이름 정하기 화면에 미리 채울 이름 (`suggestedName`, Apple 첫 로그인 이름)
  String? get suggestedName;

  /// 앱 시작 때: 저장된 토큰으로 `GET /users/me`
  Future<void> restore();

  Future<SignInResult> signInKakao();

  Future<SignInResult> signInApple();

  /// Google 로그인 (Android) → `POST /auth/google`
  Future<SignInResult> signInGoogle();

  /// 개발 로그인 (`POST /auth/dev`) — 개발 빌드에서만 보인다.
  Future<SignInResult> signInDev({required String key, String? name});

  /// 이름 정하기 (`PATCH /users/me { name }`) → signedIn
  Future<Result<void>> setName(String name);

  /// 로그아웃: `DELETE /notifications/devices/{token}` → `POST /auth/logout` → 토큰 지우기
  Future<void> logout();

  /// 탈퇴했거나 refresh가 실패했다 — 토큰을 지우고 로그인 화면으로.
  Future<void> signedOutByServer();
}
