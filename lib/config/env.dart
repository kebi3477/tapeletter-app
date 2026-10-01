import 'package:flutter/foundation.dart';

/// 빌드할 때 `--dart-define`으로 넣는 값.
///
/// Xcode에서 빌드하거나 dart-define 없이 빌드해도 운영용으로 동작하도록 기본값을 둔다.
/// 공개값(카카오 네이티브 앱 키, 링크 도메인)은 항상 기본값이 있고, 서버 주소는
/// release 빌드에서만 운영 서버가 기본값이다(debug·테스트는 비워 두어 가짜 서버를 쓴다).
abstract final class Env {
  static const _prodApiBaseUrl = 'https://tapeletter.lab241.com/api';

  /// AdMob 보상형 광고 단위 ID. 비어 있으면 광고를 디자인의 광고 시트로 흉내 낸다
  /// (가짜 광고는 개발 전용 `POST /dev/credits`로 보상하므로 운영 서버에서는 쓸 수 없다).
  /// release 빌드는 플랫폼별 실제 광고 단위가 기본값이다. debug에서 실제 광고를 보려면
  /// Google 테스트 광고 단위를 넣는다 (자기 광고를 직접 보면 무효 트래픽이 된다).
  static const _admobRewardedIdOverride = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
  );
  static const _admobRewardedIos = 'ca-app-pub-6280185901199691/7070993115';
  static const _admobRewardedAndroid = 'ca-app-pub-6280185901199691/5757911441';

  static String get admobRewardedId {
    if (_admobRewardedIdOverride.isNotEmpty) return _admobRewardedIdOverride;
    if (!kReleaseMode) return '';
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _admobRewardedIos
        : _admobRewardedAndroid;
  }

  /// AdMob 테스트 기기 ID (쉼표로 구분). 개발자 기기에서 실제 광고 대신 테스트 광고를 받는다.
  /// 기기 ID는 광고를 한 번 요청하면 SDK가 로그에 찍는다 (docs/SETUP.md).
  /// 기본값: 개발자 iPhone(kebi_ko). 이 기기에서만 테스트 광고가 나오고 다른 기기에는 영향이 없다.
  static const _admobTestDeviceIds = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS',
    defaultValue: '5733e92cf4dcc31c58a2c41c8b9656b1',
  );

  static List<String> get admobTestDeviceIds => _admobTestDeviceIds
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// true면 App Store / Google Play 결제를 쓴다. 아니면 가짜 결제(1.4초 뒤 성공, 개발 전용
  /// `POST /dev/credits`). release 빌드는 실제 결제가 기본값이다.
  static const iapEnabled = bool.fromEnvironment(
    'IAP_ENABLED',
    defaultValue: kReleaseMode,
  );

  /// 카카오 네이티브 앱 키. 앱에 들어가는 공개 키라 기본값을 둔다 (iOS는 Env.xcconfig에도 같은 값).
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: 'b53a18d3cc2caf80784d6ffd8bddb7c4',
  );

  /// Google 로그인(Android)의 `serverClientId` — Google Cloud **웹** OAuth 클라이언트 ID.
  /// 앱에 들어가는 공개값이라 기본값을 둔다. dart-define 값이 비어 있으면(`dart_defines/*.json`의
  /// 빈 자리) 기본값을 쓴다. 둘 다 비어 있으면 Google 버튼을 눌렀을 때 로그인 실패 토스트가
  /// 뜬다 (docs/SETUP.md).
  static const _googleServerClientIdOverride = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _googleServerClientIdDefault = '';

  static String get googleServerClientId =>
      _googleServerClientIdOverride.isNotEmpty
      ? _googleServerClientIdOverride
      : _googleServerClientIdDefault;

  /// 링크 도메인 (`https://<PUBLIC_HOST>/t/{token}`).
  static const publicHost = String.fromEnvironment(
    'PUBLIC_HOST',
    defaultValue: 'tapeletter.lab241.com',
  );

  /// 실제 서버 주소 (예: `http://localhost:3000/api`). 비어 있으면 서버 없이 도는 가짜 서버를 쓴다.
  /// release 빌드는 따로 넣지 않으면 운영 서버를 쓴다.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? _prodApiBaseUrl : '',
  );
}
