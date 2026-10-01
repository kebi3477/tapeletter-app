import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/dependencies.dart';
import 'config/env.dart';
import 'config/resume_refresh.dart';
import 'data/services/ad_service.dart';
import 'data/services/local/local_device_services.dart';
import 'data/services/push_service.dart';
import 'data/services/sound_service.dart';
import 'routing/app_flow.dart';
import 'routing/router.dart';
import 'routing/routes.dart';
import 'ui/core/themes/theme.dart';
import 'ui/core/ui/toast.dart';
import 'ui/link/view_model/link_view_model.dart';
import 'ui/player/view_model/player_view_model.dart';
import 'ui/push/view_model/push_view_model.dart';
import 'ui/push/widgets/push_banner.dart';
import 'ui/status/view_model/status_view_model.dart';
import 'ui/status/widgets/status_overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 광고 단위 ID가 있을 때만 광고 SDK를 켠다.
  if (Env.admobRewardedId.isNotEmpty) {
    await AdMobAdService.initialize(testDeviceIds: Env.admobTestDeviceIds);
  }
  // Firebase 설정 파일이 없으면 가짜 푸시로 돈다.
  final push = await FirebasePushService.create() ?? LocalPushService();
  // 효과음(녹음 탭 데크 키 전용)은 미리 읽어 둔다.
  final sound = PlatformSoundService();
  unawaited(sound.preload());

  runApp(
    MultiProvider(
      providers: [
        Provider<SoundService>.value(value: sound),
        ...providers(push: push),
        ...appViewModels,
      ],
      child: const TapeletterApp(),
    ),
  );
}

class TapeletterApp extends StatefulWidget {
  const TapeletterApp({super.key, this.initialLocation = Routes.splash});

  final String initialLocation;

  @override
  State<TapeletterApp> createState() => _TapeletterAppState();
}

class _TapeletterAppState extends State<TapeletterApp> {
  late final GoRouter _router = router(
    initialLocation: widget.initialLocation,
    flow: context.read<AppFlow>(),
  );
  final List<StreamSubscription<Object?>> _subs = [];

  /// 백그라운드에서 돌아오면 서랍·크레딧·친구를 다시 (30초에 한 번까지)
  late final ResumeRefresh _refresh = ResumeRefresh(
    auth: context.read(),
    users: context.read(),
    friends: context.read(),
    wallet: context.read(),
    shelf: context.read(),
  );
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh.onResumed);
    _subs.add(context.read<LinkViewModel>().events.listen(_onLink));
    _subs.add(context.read<PushViewModel>().opens.listen(_onPush));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  /// 탭으로 간 뒤, 그 탭이 그려지고 나서 오버레이를 연다 (같은 프레임에 push하면 go에 덮인다).
  void _goThenPush(String tab, String? overlay) {
    _router.go(tab);
    if (overlay == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _router.push(overlay);
    });
  }

  /// 링크로 받은 테이프 → 서랍 + 소포 화면, 오류 → 링크 오류 화면
  void _onLink(LinkEvent e) {
    switch (e) {
      case OpenLinkParcel(:final token):
        _goThenPush(Routes.shelf, Routes.playLink(token));
      case OpenClaimedParcel(:final itemId, :final friendMade):
        _goThenPush(
          Routes.shelf,
          Routes.playItem(const UnsortedSource(), itemId, linkChip: friendMade),
        );
      case ShowLinkError(:final kind, :final url):
        _router.push(Routes.linkErrorOf(kind.name, url: url));
    }
  }

  /// 푸시를 눌렀다 → 테이프면 서랍 + 소포, 선물이면 크레딧 내역, 받음이면 보낸 테이프 상세
  void _onPush(PushMessage m) {
    switch (m.kind) {
      case PushKind.tape:
        final id = m.deliveryId;
        _goThenPush(
          Routes.shelf,
          id == null ? null : Routes.playItem(const UnsortedSource(), id),
        );
      case PushKind.gift:
        _goThenPush(Routes.my, Routes.credits);
      case PushKind.claimed:
        // 링크 테이프를 받았다 → 보낸 테이프 상세
        final id = m.deliveryId;
        _router.go(id == null ? Routes.my : Routes.mySent(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'tapeletter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
      // 화면 위에 겹치는 배너·오류 화면·토스트. 내비게이터 밖이라 글자 기본 모양을 여기서 준다.
      builder: (context, child) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            ?child,
            OfflineBanner(viewModel: context.read<StatusViewModel>()),
            PushBannerHost(viewModel: context.read<PushViewModel>()),
            ServerErrorOverlay(viewModel: context.read<StatusViewModel>()),
            ToastHost(controller: context.read<ToastController>()),
          ],
        ),
      ),
    );
  }
}
