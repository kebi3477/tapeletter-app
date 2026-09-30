import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/auth_repository_remote.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/share_repository.dart';
import '../data/repositories/share_repository_remote.dart';
import '../data/services/api/api_status.dart';
import '../data/services/api/authorized_api_client.dart';
import '../data/services/api/http_api_client.dart';
import '../data/services/audio_cache.dart';
import '../data/services/http_upload_service.dart';
import '../data/services/api/token_store.dart';
import '../data/services/app_prefs.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/deep_link_service.dart';
import '../data/services/local/local_device_services.dart';
import '../data/services/push_service.dart';
import '../data/services/social_auth_service.dart';
import '../routing/app_flow.dart';
import '../ui/link/view_model/link_view_model.dart';
import '../ui/push/view_model/push_view_model.dart';
import '../ui/status/view_model/status_view_model.dart';
import '../data/repositories/delivery_repository.dart';
import '../data/repositories/delivery_repository_remote.dart';
import '../data/repositories/friend_repository.dart';
import '../data/repositories/friend_repository_remote.dart';
import '../data/repositories/recording_repository.dart';
import '../data/repositories/recording_repository_remote.dart';
import '../data/repositories/shelf_repository.dart';
import '../data/repositories/shelf_repository_remote.dart';
import '../data/repositories/shop_repository.dart';
import '../data/repositories/shop_repository_remote.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/user_repository_remote.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/wallet_repository_remote.dart';
import '../data/services/api/api_client.dart';
import '../data/services/ad_service.dart';
import '../data/services/app_info_service.dart';
import '../data/services/app_settings_service.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/iap_service.dart';
import '../data/services/link_service.dart';
import '../data/services/local/local_api_client.dart';
import '../data/services/local/local_ad_service.dart';
import '../data/services/local/local_behavior.dart';
import '../data/services/local/local_iap_service.dart';
import '../data/services/local/local_store.dart';
import '../data/services/local/local_upload_service.dart';
import '../data/services/recorder_service.dart';
import '../data/services/share_service.dart';
import '../data/services/upload_service.dart';
import '../ui/core/ui/toast.dart';
import '../ui/my/view_model/my_view_model.dart';
import '../ui/record/view_model/record_view_model.dart';
import '../ui/shelf/view_model/shelf_view_model.dart';
import '../ui/shop/view_model/shop_view_model.dart';
import 'env.dart';
import '../ui/shell/view_model/shell_view_model.dart';

/// 앱 구성. `--dart-define=API_BASE_URL=`이 있으면 실제 서버([providersHttp]),
/// 없으면 서버 없이 도는 가짜 서버([providersLocal]).
List<SingleChildWidget> providers({required PushService push}) =>
    Env.apiBaseUrl.isEmpty
    ? providersLocal(push: push)
    : providersHttp(baseUrl: Env.apiBaseUrl, push: push);

/// 실제 서버. 토큰은 Keychain / Keystore([SecureTokenStore])에 둔다.
List<SingleChildWidget> providersHttp({
  required String baseUrl,
  required PushService push,
}) => _providers(
  inner: HttpApiClient(baseUrl: baseUrl),
  tokens: SecureTokenStore(),
  uploads: HttpUploadService(),
  behavior: const LocalBehavior(),
  push: push,
);

/// 서버 없이 도는 구성. [LocalApiClient]가 계약서 모양 그대로 응답하고,
/// 데이터는 프로토타입 초기 state([LocalStore])다. 녹음·재생·공유는 실제 기기 기능을 쓴다.
///
/// 실패 흉내: `flutter run --dart-define=FAIL_MODE=convertSlow`
/// (`convertSlow` · `convertFail` · `sendFail` · `loadFail` · `payFail` · `adFail` ·
/// `serverError` · `forceUpdate` · `linkTaken` · `linkExpired` · `linkOwn` ·
/// `rejoinRestricted` · `reportLimit` · `reportGone` · `offline`)
List<SingleChildWidget> providersLocal({
  LocalStore? store,
  LocalBehavior? behavior,
  required PushService push,
  DeepLinkService? deepLinks,
  ConnectivityService? connectivity,
  AppPrefs? prefs,
  TokenStore? tokens,
  SocialAuthService? social,
}) {
  final b = behavior ?? LocalBehavior.fromEnvironment();
  // 처음 로그인하면 가입이 되고 이름 정하기부터 (메모리 서버)
  final s = store ?? LocalStore(newUser: true);
  return _providers(
    inner: LocalApiClient(s, b),
    // 메모리 서버는 앱을 다시 켜면 비므로 토큰도 메모리에 둔다.
    tokens: tokens ?? MemoryTokenStore(),
    uploads: LocalUploadService(s),
    behavior: b,
    push: push,
    deepLinks: deepLinks,
    connectivity: connectivity,
    prefs: prefs,
    social: social,
  );
}

/// 모든 요청은 [AuthorizedApiClient]를 거친다 — 토큰을 붙이고 401이면 refresh 후 다시 보낸다.
List<SingleChildWidget> _providers({
  required ApiClient inner,
  required TokenStore tokens,
  required UploadService uploads,
  required LocalBehavior behavior,
  required PushService push,
  DeepLinkService? deepLinks,
  ConnectivityService? connectivity,
  AppPrefs? prefs,
  SocialAuthService? social,
}) {
  final status = ApiStatus();
  final api = AuthorizedApiClient(inner, tokens, status);
  final audioCache = FileAudioCache();
  final auth = AuthRepositoryRemote(
    api: api,
    tokens: tokens,
    social:
        social ??
        PlatformSocialAuthService(kakaoNativeAppKey: Env.kakaoNativeAppKey),
    push: push,
    audioCache: audioCache,
  );
  // refresh도 실패하면 로그인 화면으로
  api.onSessionExpired = auth.signedOutByServer;
  return [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<ApiStatus>.value(value: status),
    Provider<TokenStore>.value(value: tokens),
    Provider<UploadService>.value(value: uploads),
    Provider<AudioCache>.value(value: audioCache),
    ChangeNotifierProvider<AuthRepository>.value(value: auth),
    Provider<PushService>.value(value: push),
    Provider<DeepLinkService>.value(
      value: deepLinks ?? AppLinksDeepLinkService(),
    ),
    Provider<ConnectivityService>.value(
      value:
          connectivity ??
          (behavior.offline
              ? LocalConnectivityService(online: false)
              : PlusConnectivityService()),
    ),
    Provider<AppPrefs>.value(value: prefs ?? SharedAppPrefs()),
    ...repositories,
    ...deviceServices,
    ...storeServices(api, behavior),
  ];
}

/// 결제·광고. 키가 없으면 가짜로 돈다.
///
/// - 광고: `--dart-define=ADMOB_REWARDED_ID=<광고 단위 ID>`가 있으면 AdMob 보상형 광고
/// - 결제: `--dart-define=IAP_ENABLED=true`면 App Store / Google Play 결제
List<SingleChildWidget> storeServices(ApiClient api, LocalBehavior b) => [
  Provider<IapService>(
    create: (_) => Env.iapEnabled ? StoreIapService() : LocalIapService(b),
  ),
  Provider<AdService>(
    create: (_) => Env.admobRewardedId.isNotEmpty
        ? AdMobAdService(Env.admobRewardedId)
        : LocalAdService(api, b),
  ),
];

/// [ApiClient] 위의 repository. 구현은 HTTP로 바꿔도 그대로 쓴다.
List<SingleChildWidget> get repositories => [
  ChangeNotifierProvider<UserRepository>(
    create: (c) => UserRepositoryRemote(c.read()),
  ),
  ChangeNotifierProvider<FriendRepository>(
    create: (c) => FriendRepositoryRemote(c.read()),
  ),
  ChangeNotifierProvider<WalletRepository>(
    create: (c) => WalletRepositoryRemote(c.read()),
  ),
  ChangeNotifierProvider<ShelfRepository>(
    create: (c) => ShelfRepositoryRemote(c.read(), cache: c.read()),
  ),
  Provider<RecordingRepository>(
    create: (c) => RecordingRepositoryRemote(c.read(), c.read()),
  ),
  Provider<DeliveryRepository>(
    create: (c) => DeliveryRepositoryRemote(c.read()),
  ),
  Provider<ShopRepository>(create: (c) => ShopRepositoryRemote(c.read())),
  Provider<ShareRepository>(
    create: (c) => ShareRepositoryRemote(c.read(), c.read()),
  ),
  Provider<AppRepository>(create: (c) => AppRepository(c.read())),
  Provider<ReportRepository>(
    create: (c) => ReportRepository(c.read(), c.read()),
  ),
  Provider<DeviceRepository>(create: (c) => DeviceRepository(c.read())),
];

/// 기기 기능 (녹음·재생·공유·설정)
List<SingleChildWidget> get deviceServices => [
  Provider<RecorderService>(
    create: (_) => RecordRecorderService(),
    dispose: (_, s) => s.dispose(),
  ),
  Provider<AudioPlayerService>(
    create: (_) => JustAudioPlayerService(),
    dispose: (_, s) => s.dispose(),
  ),
  Provider<ShareService>(
    create: (_) => SystemShareService(kakaoNativeAppKey: Env.kakaoNativeAppKey),
  ),
  Provider<AppSettingsService>(create: (_) => SystemAppSettingsService()),
  Provider<LinkService>(create: (_) => UrlLauncherLinkService()),
  Provider<AppInfoService>(create: (_) => PackageAppInfoService()),
];

/// 화면 전체에서 함께 쓰는 ViewModel. repository·service 뒤에 둔다.
List<SingleChildWidget> get appViewModels => [
  ChangeNotifierProvider(create: (_) => ToastController()),
  ChangeNotifierProvider(
    lazy: false,
    create: (c) => AppFlow(
      auth: c.read(),
      prefs: c.read(),
      app: c.read(),
      appInfo: c.read(),
      platform: c.read<PushService>().platform,
      onSignedIn: () => reloadSession(c),
    )..boot(),
  ),
  ChangeNotifierProvider(
    lazy: false,
    create: (c) => StatusViewModel(
      connectivity: c.read(),
      apiStatus: c.read(),
      app: c.read(),
      toast: c.read(),
      onRecovered: () => reloadSession(c),
    )..start(),
  ),
  ChangeNotifierProvider(
    lazy: false,
    create: (c) => LinkViewModel(
      deepLinks: c.read(),
      prefs: c.read(),
      share: c.read(),
      flow: c.read(),
      toast: c.read(),
      publicHost: Env.publicHost,
    )..start(),
  ),
  ChangeNotifierProvider(
    lazy: false,
    create: (c) => PushViewModel(
      push: c.read(),
      devices: c.read(),
      auth: c.read(),
      flow: c.read(),
      shelf: c.read(),
      wallet: c.read(),
      users: c.read(),
    )..start(),
  ),
  ChangeNotifierProvider(
    create: (c) =>
        ShellViewModel(userRepository: c.read(), shelfRepository: c.read())
          ..load(),
  ),
  ChangeNotifierProvider(
    create: (c) => ShelfViewModel(
      shelfRepository: c.read(),
      toast: c.read(),
      prefs: c.read(),
      friends: c.read(),
    )..load(),
  ),
  ChangeNotifierProvider(
    create: (c) => ShopViewModel(
      shopRepository: c.read(),
      walletRepository: c.read(),
      userRepository: c.read(),
      friendRepository: c.read(),
      shelfRepository: c.read(),
      iap: c.read(),
      ads: c.read(),
      toast: c.read(),
    )..load(),
  ),
  ChangeNotifierProvider(
    create: (c) => MyViewModel(
      userRepository: c.read(),
      friendRepository: c.read(),
      walletRepository: c.read(),
      deliveryRepository: c.read(),
      authRepository: c.read(),
      shelfRepository: c.read(),
      share: c.read(),
      links: c.read(),
      appInfo: c.read(),
      toast: c.read(),
    )..load(),
  ),
  ChangeNotifierProvider(
    create: (c) => RecordViewModel(
      userRepository: c.read(),
      friendRepository: c.read(),
      walletRepository: c.read(),
      recordingRepository: c.read(),
      deliveryRepository: c.read(),
      recorder: c.read(),
      player: c.read(),
      share: c.read(),
      settings: c.read(),
      toast: c.read(),
      sound: c.read(),
    )..load(),
  ),
];

/// 로그인·서버 복구 뒤: 화면 데이터를 새로 불러오게 repository에 알린다.
void reloadSession(BuildContext c) {
  c.read<UserRepository>().invalidate();
  c.read<FriendRepository>().invalidate();
  c.read<WalletRepository>().invalidate();
  c.read<ShelfRepository>().invalidate();
}
