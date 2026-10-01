import 'dart:async';
import 'dart:io' show Platform;

import '../connectivity_service.dart';
import '../deep_link_service.dart';
import '../push_service.dart';
import '../social_auth_service.dart';

/// 소셜 로그인 흉내 — 바로 성공한다 (메모리 서버는 토큰을 확인하지 않는다).
class LocalSocialAuthService implements SocialAuthService {
  SocialLogin kakaoResult = const KakaoLogin('local-kakao');
  SocialLogin appleResult = const AppleLogin(
    identityToken: 'local-apple',
    authorizationCode: 'local-code',
  );
  SocialLogin googleResult = const GoogleLogin('local-google');

  /// 있으면 카카오 로그인이 이 Future가 끝날 때까지 기다린다 (카카오톡에서 돌아오지 않는 경우 흉내).
  Completer<SocialLogin>? kakaoPending;

  @override
  Future<SocialLogin> kakao() async => kakaoPending?.future ?? kakaoResult;

  @override
  Future<SocialLogin> apple() async => appleResult;

  @override
  Future<SocialLogin> google() async => googleResult;
}

/// Firebase 설정이 없을 때의 푸시. [simulate]로 앱 안 배너를 띄워 볼 수 있다.
class LocalPushService extends PushService {
  LocalPushService({
    this.granted = true,
    this.deviceToken = 'local-device',
    String? platform,
  }) : platform = platform ?? (Platform.isAndroid ? 'android' : 'ios');

  bool granted;
  String? deviceToken;
  PushMessage? initial;
  final _fg = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  final _token = StreamController<String>.broadcast();
  int permissionRequests = 0;

  /// 앱이 켜져 있을 때 푸시가 온 것처럼
  void simulate(PushMessage m) => _fg.add(m);

  /// 알림을 눌러 앱이 열린 것처럼
  void simulateOpened(PushMessage m) => _opened.add(m);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<String?> token() async => deviceToken;

  @override
  Stream<String> get onTokenRefresh => _token.stream;

  @override
  Stream<PushMessage> get onForeground => _fg.stream;

  @override
  Stream<PushMessage> get onOpened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;

  @override
  final String platform;
}

/// 링크를 코드로 흘려 보낼 수 있는 가짜
class LocalDeepLinkService implements DeepLinkService {
  Uri? initial;
  final _links = StreamController<Uri>.broadcast();

  void open(Uri uri) => _links.add(uri);

  @override
  Future<Uri?> initialLink() async => initial;

  @override
  Stream<Uri> get links => _links.stream;
}

/// 연결 상태 가짜 — `FAIL_MODE=offline`이면 처음부터 오프라인
class LocalConnectivityService implements ConnectivityService {
  LocalConnectivityService({this._online = true});

  bool _online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool online) {
    _online = online;
    _changes.add(online);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;
}
