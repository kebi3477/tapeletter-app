import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/buttons.dart';
import '../view_model/permissions_view_model.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

/// 마이크 권한 안내 (`auMic`) — 계속 → OS 권한 창 → 알림 안내
class MicPromptScreen extends StatelessWidget {
  const MicPromptScreen({
    super.key,
    required this.viewModel,
    required this.onNext,
  });

  final PermissionsViewModel viewModel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _PromptScaffold(
      graphic: const _PulsingRecordDot(),
      title: '녹음하려면\n마이크가 필요해요',
      body: '테이프에 목소리를 담을 때만 써요.\n녹음 버튼을 누르기 전에는 듣지 않아요.',
      buttons: [
        AppButton(
          label: '계속',
          onTap: () async {
            if (await viewModel.askMic()) onNext();
          },
        ),
      ],
    );
  }
}

/// 알림 권한 안내 (`auNoti`) — 알림 받기(OS 권한 창) / 나중에 할게요
class NotiPromptScreen extends StatelessWidget {
  const NotiPromptScreen({super.key, required this.viewModel});

  final PermissionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _PromptScaffold(
      padding: 24,
      graphic: const _BannerPreview(),
      title: '테이프가 도착하면\n알려드려요',
      body: '소포가 오면 바로 뜯어볼 수 있게요',
      buttons: [
        AppButton(label: '알림 받기', onTap: viewModel.askNotifications),
        const SizedBox(height: 2),
        Tappable(
          behavior: HitTestBehavior.opaque,
          onTap: viewModel.later,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Text(
                keepAll('나중에 할게요'),
                style: AppText.suit(600, 14, color: AppColors.textSub),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromptScaffold extends StatelessWidget {
  const _PromptScaffold({
    required this.graphic,
    required this.title,
    required this.body,
    required this.buttons,
    this.padding = 32,
  });

  final Widget graphic;
  final String title;
  final String body;
  final List<Widget> buttons;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: SlideUp(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      graphic,
                      const SizedBox(height: 34),
                      Text(
                        keepAll(title),
                        textAlign: TextAlign.center,
                        style: AppText.suit(
                          800,
                          26,
                          height: 1.3,
                          letterSpacingEm: -.02,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        keepAll(body),
                        textAlign: TextAlign.center,
                        style: AppText.suit(
                          500,
                          15,
                          height: 1.55,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottomSafe(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: buttons,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 112 링(2px `#E6E6E3`) 안에 84 레드 원, `pulse 1.6s`
class _PulsingRecordDot extends StatefulWidget {
  const _PulsingRecordDot();

  @override
  State<_PulsingRecordDot> createState() => _PulsingRecordDotState();
}

class _PulsingRecordDotState extends State<_PulsingRecordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // pulse가 box-shadow를 바꾸므로 링 대신 펄스만 보인다.
        final t = Curves.easeOut.transform(_c.value);
        return Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: AppColors.paper,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.recPulse.withValues(
                  alpha: AppColors.recPulse.a * (1 - t),
                ),
                spreadRadius: 18 * t,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// 알림 미리보기 카드 (320, `bannerIn .5s .1s`)
class _BannerPreview extends StatefulWidget {
  const _BannerPreview();

  @override
  State<_BannerPreview> createState() => _BannerPreviewState();
}

class _BannerPreviewState extends State<_BannerPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final k = AppMotion.snap.transform(_c.value);
        return FractionalTranslation(
          translation: Offset(0, -1.3 * (1 - k)),
          child: child,
        );
      },
      child: const SizedBox(
        width: 320,
        child: PushCard(
          title: '지현님이 테이프를 보냈어요',
          body: '15초 테이프가 도착했어요',
          background: AppColors.surfaceSoft,
        ),
      ),
    );
  }
}

/// 푸시 모양 카드 (radius 22, 아이콘 38, tapeletter · 지금, 제목·본문)
class PushCard extends StatelessWidget {
  const PushCard({
    super.key,
    required this.title,
    required this.body,
    required this.background,
  });

  final String title;
  final String body;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: .3),
            offset: const Offset(0, 12),
            blurRadius: 30,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const SvgIcon(AppIcons.symbolWhite, width: 28, height: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('tapeletter', style: AppText.suit(700, 13)),
                    Text(
                      '지금',
                      style: AppText.suit(500, 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  keepAll(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.suit(700, 14),
                ),
                const SizedBox(height: 1),
                Text(
                  keepAll(body),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.suit(500, 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
