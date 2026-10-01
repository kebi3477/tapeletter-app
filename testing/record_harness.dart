import 'package:tapeletter_app/data/repositories/app_repository.dart';
import 'package:tapeletter_app/data/repositories/report_repository.dart';
import 'package:tapeletter_app/data/repositories/auth_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/device_repository.dart';
import 'package:tapeletter_app/data/repositories/share_repository_remote.dart';
import 'package:tapeletter_app/data/services/api/api_status.dart';
import 'package:tapeletter_app/data/services/api/authorized_api_client.dart';
import 'package:tapeletter_app/data/services/api/token_store.dart';
import 'package:tapeletter_app/data/services/app_prefs.dart';
import 'package:tapeletter_app/data/services/local/local_device_services.dart';
import 'package:tapeletter_app/data/repositories/friend_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/shop_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/shelf_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/user_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/wallet_repository_remote.dart';
import 'package:tapeletter_app/data/services/local/local_ad_service.dart';
import 'package:tapeletter_app/data/services/local/local_api_client.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/routing/app_flow.dart';
import 'package:tapeletter_app/ui/core/ui/toast.dart';
import 'package:tapeletter_app/ui/link/view_model/link_view_model.dart';
import 'package:tapeletter_app/ui/my/view_model/my_view_model.dart';
import 'package:tapeletter_app/ui/record/view_model/record_view_model.dart';
import 'package:tapeletter_app/ui/shop/view_model/shop_view_model.dart';

import 'fakes/repositories/fake_delivery_repository.dart';
import 'fakes/repositories/fake_recording_repository.dart';
import 'fakes/services/fake_app_settings_service.dart';
import 'fakes/services/fake_audio_player_service.dart';
import 'fakes/services/fake_iap_service.dart';
import 'fakes/services/fake_link_service.dart';
import 'fakes/services/fake_recorder_service.dart';
import 'fakes/services/fake_sound_service.dart';
import 'fakes/services/fake_share_service.dart';

/// 프로토타입 초기 데이터(친구 6명, 보유 {3:2, 5:0} 등)를 계약서 모양으로 돌려주는
/// 지연 없는 [LocalApiClient] + 가짜 기기 기능으로 앱 조각을 만든다.
class RecordHarness {
  RecordHarness({
    FakeRecorderService? recorder,
    FakeRecordingRepository? recordings,
    FakeDeliveryRepository? deliveries,
    LocalBehavior behavior = LocalBehavior.instant,
    LocalStore? store,
    bool signedIn = true,
    bool onboarded = true,
    bool permissionsAsked = true,
  }) : recorder = recorder ?? FakeRecorderService(),
       recordings = recordings ?? FakeRecordingRepository(),
       store = store ?? LocalStore(clock: () => DateTime.utc(2026, 9, 25, 3)),
       prefs = MemoryAppPrefs(
         onboardedValue: onboarded,
         permissionsValue: permissionsAsked,
       ) {
    api = LocalApiClient(this.store, behavior);
    // 앱과 같이 토큰을 붙이고 401이면 refresh하는 client를 거친다.
    client = AuthorizedApiClient(api, tokens, apiStatus);
    if (signedIn) {
      final t = api.issueTokensForTest();
      tokens.tokens = AuthTokens(
        access: t.accessToken,
        refresh: t.refreshToken,
      );
    }
    auth = AuthRepositoryRemote(
      api: client,
      tokens: tokens,
      social: social,
      push: push,
    );
    client.onSessionExpired = auth.signedOutByServer;
    users = UserRepositoryRemote(client);
    friends = FriendRepositoryRemote(client);
    wallet = WalletRepositoryRemote(client);
    shelf = ShelfRepositoryRemote(client);
    shareRepo = ShareRepositoryRemote(client, shelf, friends);
    app = AppRepository(client);
    reports = ReportRepository(client, friends);
    devices = DeviceRepository(client);
    this.deliveries = deliveries ?? FakeDeliveryRepository(store: this.store);
    shop = ShopRepositoryRemote(client);
    ads = LocalAdService(api, behavior);
    shopVm = ShopViewModel(
      shopRepository: shop,
      walletRepository: wallet,
      userRepository: users,
      friendRepository: friends,
      shelfRepository: shelf,
      iap: iap,
      ads: ads,
      toast: toast,
    );
    myVm = MyViewModel(
      userRepository: users,
      friendRepository: friends,
      walletRepository: wallet,
      deliveryRepository: this.deliveries,
      authRepository: auth,
      shelfRepository: shelf,
      share: share,
      links: links,
      appInfo: FakeAppInfoService(),
      toast: toast,
    );
    vm = RecordViewModel(
      userRepository: users,
      friendRepository: friends,
      walletRepository: wallet,
      recordingRepository: this.recordings,
      deliveryRepository: this.deliveries,
      recorder: this.recorder,
      player: player,
      share: share,
      settings: settings,
      toast: toast,
      sound: sound,
    );
  }

  final LocalStore store;
  late final LocalApiClient api;
  late final AuthorizedApiClient client;
  final ApiStatus apiStatus = ApiStatus();
  final MemoryTokenStore tokens = MemoryTokenStore();
  final MemoryAppPrefs prefs;
  final LocalSocialAuthService social = LocalSocialAuthService();
  final LocalPushService push = LocalPushService();
  final LocalDeepLinkService deepLinks = LocalDeepLinkService();
  final LocalConnectivityService connectivity = LocalConnectivityService();
  late final AuthRepositoryRemote auth;
  late final ShareRepositoryRemote shareRepo;
  late final AppRepository app;
  late final ReportRepository reports;
  late final DeviceRepository devices;
  late final UserRepositoryRemote users;
  late final FriendRepositoryRemote friends;
  late final WalletRepositoryRemote wallet;
  late final ShelfRepositoryRemote shelf;
  final FakeRecorderService recorder;

  /// 효과음 — 녹음기 호출(`recorder.calls`)과 같은 목록에 적는다.
  late final FakeSoundService sound = FakeSoundService(log: recorder.calls);
  final FakeRecordingRepository recordings;
  late final FakeDeliveryRepository deliveries;
  final FakeAudioPlayerService player = FakeAudioPlayerService();
  final FakeShareService share = FakeShareService();
  final FakeAppSettingsService settings = FakeAppSettingsService();
  final ToastController toast = ToastController();
  late final RecordViewModel vm;
  late final ShopRepositoryRemote shop;
  late final LocalAdService ads;
  final FakeIapService iap = FakeIapService();
  final FakeLinkService links = FakeLinkService();
  late final ShopViewModel shopVm;

  /// 처음 실행 관문. 스플래시는 바로 끝난 것으로 둔다.
  late final AppFlow flow =
      AppFlow(
          auth: auth,
          prefs: prefs,
          app: app,
          appInfo: FakeAppInfoService(),
          platform: 'ios',
          onSignedIn: () {
            users.invalidate();
            friends.invalidate();
            wallet.invalidate();
            shelf.invalidate();
          },
        )
        ..finishSplash()
        ..boot();

  late final LinkViewModel linkVm = LinkViewModel(
    deepLinks: deepLinks,
    prefs: prefs,
    share: shareRepo,
    flow: flow,
    toast: toast,
    publicHost: 'tapeletter.example',
  )..start();
  late final MyViewModel myVm;
}
