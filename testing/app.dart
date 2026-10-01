import 'package:tapeletter_app/data/repositories/app_repository.dart';
import 'package:tapeletter_app/data/repositories/auth_repository.dart';
import 'package:tapeletter_app/data/repositories/report_repository.dart';
import 'package:tapeletter_app/data/repositories/device_repository.dart';
import 'package:tapeletter_app/data/repositories/friend_repository.dart';
import 'package:tapeletter_app/data/repositories/share_repository.dart';
import 'package:tapeletter_app/data/services/sound_service.dart';
import 'package:tapeletter_app/data/services/api/api_client.dart';
import 'package:tapeletter_app/data/services/api/api_status.dart';
import 'package:tapeletter_app/data/services/app_info_service.dart';
import 'package:tapeletter_app/data/services/app_prefs.dart';
import 'package:tapeletter_app/data/services/connectivity_service.dart';
import 'package:tapeletter_app/data/services/deep_link_service.dart';
import 'package:tapeletter_app/data/services/link_service.dart';
import 'package:tapeletter_app/data/services/push_service.dart';
import 'package:tapeletter_app/data/services/recorder_service.dart';
import 'package:tapeletter_app/data/services/share_service.dart';
import 'package:tapeletter_app/routing/app_flow.dart';
import 'package:tapeletter_app/ui/link/view_model/link_view_model.dart';
import 'package:tapeletter_app/ui/push/view_model/push_view_model.dart';
import 'package:tapeletter_app/ui/status/view_model/status_view_model.dart';
import 'package:tapeletter_app/data/repositories/shelf_repository.dart';
import 'package:tapeletter_app/data/repositories/user_repository.dart';
import 'package:tapeletter_app/data/repositories/wallet_repository.dart';
import 'package:tapeletter_app/data/services/audio_player_service.dart';
import 'package:tapeletter_app/main.dart';
import 'package:tapeletter_app/routing/routes.dart';
import 'package:tapeletter_app/ui/core/ui/toast.dart';
import 'package:tapeletter_app/ui/my/view_model/my_view_model.dart';
import 'package:tapeletter_app/ui/record/view_model/record_view_model.dart';
import 'package:tapeletter_app/ui/shop/view_model/shop_view_model.dart';
import 'package:tapeletter_app/ui/shelf/view_model/shelf_view_model.dart';
import 'package:tapeletter_app/ui/shell/view_model/shell_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/services/fake_link_service.dart';
import 'record_harness.dart';

/// 기준 화면 390×844 (@1x)
void useDesignScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 가짜 repository·service로 앱 전체를 띄운다.
/// 관문(스플래시·로그인…)은 [RecordHarness]의 상태대로 거친다. 스플래시는 건너뛴다.
Widget testApp(RecordHarness h, {String initialLocation = Routes.record}) {
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: h.client),
      ChangeNotifierProvider<ApiStatus>.value(value: h.apiStatus),
      ChangeNotifierProvider<AuthRepository>.value(value: h.auth),
      Provider<AppPrefs>.value(value: h.prefs),
      Provider<AppRepository>.value(value: h.app),
      Provider<ReportRepository>.value(value: h.reports),
      Provider<DeviceRepository>.value(value: h.devices),
      Provider<ShareRepository>.value(value: h.shareRepo),
      Provider<AppInfoService>.value(value: FakeAppInfoService()),
      Provider<PushService>.value(value: h.push),
      Provider<DeepLinkService>.value(value: h.deepLinks),
      Provider<ConnectivityService>.value(value: h.connectivity),
      Provider<RecorderService>.value(value: h.recorder),
      Provider<ShareService>.value(value: h.share),
      Provider<LinkService>.value(value: h.links),
      ChangeNotifierProvider<UserRepository>.value(value: h.users),
      ChangeNotifierProvider<FriendRepository>.value(value: h.friends),
      ChangeNotifierProvider<WalletRepository>.value(value: h.wallet),
      ChangeNotifierProvider<ShelfRepository>.value(value: h.shelf),
      Provider<AudioPlayerService>.value(value: h.player),
      Provider<SoundService>.value(value: h.sound),
      ChangeNotifierProvider<ToastController>.value(value: h.toast),
      ChangeNotifierProvider(
        create: (c) =>
            ShellViewModel(userRepository: h.users, shelfRepository: h.shelf)
              ..load(),
      ),
      ChangeNotifierProvider(
        create: (c) => ShelfViewModel(
          shelfRepository: h.shelf,
          toast: h.toast,
          prefs: h.prefs,
          friends: h.friends,
        )..load(),
      ),
      ChangeNotifierProvider<RecordViewModel>.value(value: h.vm..load()),
      ChangeNotifierProvider<ShopViewModel>.value(value: h.shopVm..load()),
      ChangeNotifierProvider<MyViewModel>.value(value: h.myVm..load()),
      ChangeNotifierProvider<AppFlow>.value(value: h.flow),
      ChangeNotifierProvider(
        create: (c) => StatusViewModel(
          connectivity: h.connectivity,
          apiStatus: h.apiStatus,
          app: h.app,
          toast: h.toast,
        )..start(),
      ),
      ChangeNotifierProvider<LinkViewModel>.value(value: h.linkVm),
      ChangeNotifierProvider(
        create: (c) => PushViewModel(
          push: h.push,
          devices: h.devices,
          auth: h.auth,
          flow: h.flow,
          shelf: h.shelf,
          wallet: h.wallet,
          users: h.users,
          friends: h.friends,
        )..start(),
      ),
    ],
    child: TapeletterApp(initialLocation: initialLocation),
  );
}
