import 'package:tapeletter_app/data/model/api_error.dart';
import 'package:tapeletter_app/data/repositories/auth_repository.dart';
import 'package:tapeletter_app/data/repositories/auth_repository_remote.dart';
import 'package:tapeletter_app/data/services/audio_cache.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/data/services/social_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/record_harness.dart';

void main() {
  RecordHarness fresh({FailMode mode = FailMode.none}) => RecordHarness(
    store: LocalStore(
      clock: () => DateTime.utc(2026, 9, 25, 12),
      newUser: true,
    ),
    behavior: LocalBehavior.instant.copyWith(failMode: mode, requireAuth: true),
    signedIn: false,
  );

  test('저장된 토큰이 없으면 로그아웃 상태', () async {
    final h = fresh();
    await h.auth.restore();
    expect(h.auth.status, AuthStatus.signedOut);
  });

  test('카카오 처음 로그인: 토큰 저장, 이름 정하기, 추천 이름', () async {
    final h = fresh();
    final r = await h.auth.signInKakao();
    expect(r, isA<SignedIn>().having((s) => s.isNewUser, 'new', isTrue));
    expect(h.tokens.tokens, isNotNull);
    expect(h.auth.status, AuthStatus.needsName);
    expect(h.auth.suggestedName, '민경');

    await h.auth.setName('민경');
    expect(h.auth.status, AuthStatus.signedIn);
    expect(h.store.name, '민경');
  });

  test('Apple 로그인은 authorizationCode를 보낸다', () async {
    final h = fresh();
    final r = await h.auth.signInApple();
    expect(r, isA<SignedIn>());
    expect(h.auth.status, AuthStatus.needsName);
  });

  test('Google 로그인 (POST /auth/google)', () async {
    final h = fresh();
    final r = await h.auth.signInGoogle();
    expect(r, isA<SignedIn>().having((s) => s.isNewUser, 'new', isTrue));
    expect(h.tokens.tokens, isNotNull);
    expect(h.auth.status, AuthStatus.needsName);
  });

  test('Google 설정이 없거나 실패하면 일반 실패 문구', () async {
    final h = fresh();
    h.social.googleResult = const SocialFailed(
      'GOOGLE_SERVER_CLIENT_ID missing',
    );
    final r = await h.auth.signInGoogle();
    expect(
      r,
      isA<SignInFailed>().having(
        (f) => f.message,
        'message',
        '로그인하지 못했어요. 다시 시도해 주세요',
      ),
    );
    expect(h.tokens.tokens, isNull);
  });

  test('개발 로그인 (POST /auth/dev)은 이름까지 정해진다', () async {
    final h = fresh();
    await h.auth.signInDev(key: 'minkyung', name: '민경');
    expect(h.auth.status, AuthStatus.signedIn);
  });

  test('취소·키 없음', () async {
    final h = fresh();
    h.social.kakaoResult = const SocialCanceled();
    expect(await h.auth.signInKakao(), isA<SignInCanceled>());
    h.social.kakaoResult = const SocialUnavailable(
      PlatformSocialAuthService.kakaoKeyMissing,
    );
    final r = await h.auth.signInKakao();
    expect(
      r,
      isA<SignInFailed>().having(
        (f) => f.message,
        'message',
        '카카오 앱 키가 설정되지 않았어요',
      ),
    );
    expect(h.auth.status, AuthStatus.unknown);
  });

  test('403 REJOIN_RESTRICTED: 서버 문구 + 가능한 날짜', () async {
    final h = fresh(mode: FailMode.rejoinRestricted);
    final r = await h.auth.signInKakao();
    expect(
      r,
      isA<SignInFailed>().having(
        (f) => f.message,
        'message',
        '탈퇴 후 30일 동안은 다시 가입할 수 없어요 · 10.25부터 가능해요',
      ),
    );
    expect(h.tokens.tokens, isNull);
    // 개발 로그인은 막지 않는다
    await h.auth.signInDev(key: 'k', name: '민경');
    expect(h.auth.status, AuthStatus.signedIn);
  });

  test('REJOIN_RESTRICTED 문구: availableAt이 없으면 서버 문구만', () {
    const e = ApiException(
      status: 403,
      code: ApiErrorCode.rejoinRestricted,
      message: '탈퇴 후 30일 동안은 다시 가입할 수 없어요',
    );
    expect(AuthRepositoryRemote.messageOf(e), '탈퇴 후 30일 동안은 다시 가입할 수 없어요');
  });

  test('로그아웃: 기기 푸시 토큰을 먼저 지우고 refresh token을 폐기한다', () async {
    final h = fresh();
    await h.auth.signInDev(key: 'k', name: '민경');
    await h.client.registerDevice(token: 'local-device', platform: 'ios');
    final refresh = h.tokens.tokens!.refresh;
    expect(h.store.devices, contains('local-device'));

    await h.auth.logout();
    expect(h.store.devices, isEmpty);
    expect(h.store.refreshTokens, isNot(contains(refresh)));
    expect(h.tokens.tokens, isNull);
    expect(h.auth.status, AuthStatus.signedOut);
  });

  test('로그아웃·탈퇴·세션 만료면 받은 테이프 파일 캐시를 지운다', () async {
    final h = fresh();
    final cache = _CountingCache();
    final auth = AuthRepositoryRemote(
      api: h.client,
      tokens: h.tokens,
      social: h.social,
      push: h.push,
      audioCache: cache,
    );
    await auth.signInDev(key: 'k', name: '민경');
    await auth.logout();
    expect(cache.clears, 1);
    await auth.signedOutByServer();
    expect(cache.clears, 2);
  });
}

class _CountingCache implements AudioCache {
  int clears = 0;

  @override
  Future<void> clear() async => clears++;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
