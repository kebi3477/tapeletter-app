import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../routing/app_flow.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/parcel_box.dart';
import '../../core/ui/tape_widget.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

/// 온보딩 (`auOnb`) — 3장, 다음 / 건너뛰기.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.flow});

  final AppFlow flow;

  /// logic.js `onb` — 제목은 줄바꿈을 살리고(`pre-line`), 설명의 줄바꿈은 한 줄로 이어 붙인다(`split('\n').join(' ')`).
  static const pages = [
    ('목소리를 테이프에 담아요', '15초, 1분, 3분. 길이를 골라 하고 싶은 말을 녹음해요'),
    ('소포로 포장해서 보내요', '받는 사람만 뜯어서 들을 수 있어요'),
    ('소중한 목소리를\n추억별로 모아 보세요', '사람, 순간, 주제별로 칸을 만들어 오래 간직할 수 있어요'),
  ];

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _i = 0;

  void _next() {
    if (_i < 2) {
      setState(() => _i++);
    } else {
      widget.flow.finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, sub) = OnboardingScreen.pages[_i];
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Tappable(
                    onTap: widget.flow.finishOnboarding,
                    child: Text(
                      '건너뛰기',
                      style: AppText.suit(600, 14, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 230,
                    child: Center(
                      child: FadeUp(
                        key: ValueKey(_i),
                        duration: const Duration(milliseconds: 450),
                        child: switch (_i) {
                          0 => const TapeWidget(
                            packL: 40,
                            packR: 42,
                            spinning: true,
                          ),
                          1 => const _ShakingParcel(),
                          _ => const _DrawerShelves(),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
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
                          keepAll(sub),
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
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomSafe(context)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var d = 0; d < 3; d++) ...[
                        if (d > 0) const SizedBox(width: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: d == _i ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: d == _i
                                ? AppColors.ink
                                : AppColors.toggleOff,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  AppButton(label: _i < 2 ? '다음' : '시작하기', onTap: _next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2장: 흔들리는 크라프트 박스 (받는 사람 지현)
class _ShakingParcel extends StatefulWidget {
  const _ShakingParcel();

  @override
  State<_ShakingParcel> createState() => _ShakingParcelState();
}

class _ShakingParcelState extends State<_ShakingParcel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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
        final deg = keyframes(
          _c.value,
          const [0, .7, .75, .8, .85, .9, 1],
          const [0, 0, -3, 3, -2, 2, 0],
          curve: Curves.easeInOut,
        );
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
      child: SizedBox.fromSize(
        size: ParcelBox.size,
        child: const ParcelBoxFront(recipient: '지현'),
      ),
    );
  }
}

/// 3장 (v3 `onb2`): 칸 이름 4개가 붙은 책장 — 280 너비, 2열 (간격 14 · 10)
class _DrawerShelves extends StatelessWidget {
  const _DrawerShelves();

  static const _shelves = [
    (
      '2026 생일',
      [
        (TapePalette.s15, 54.0),
        (TapePalette.m1, 58.0),
        (TapePalette.m3, 50.0),
        (TapePalette.s15, 56.0),
      ],
    ),
    (
      '우리의 여행',
      [(TapePalette.m1, 56.0), (TapePalette.m1, 52.0), (TapePalette.m3, 58.0)],
    ),
    (
      '엄마 목소리',
      [
        (TapePalette.m3, 58.0),
        (TapePalette.s15, 52.0),
        (TapePalette.m3, 55.0),
        (TapePalette.m1, 50.0),
      ],
    ),
    ('힘들 때 듣기', [(TapePalette.s15, 56.0), (TapePalette.m1, 53.0)]),
  ];

  @override
  Widget build(BuildContext context) {
    Widget row(int a) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Shelf(data: _shelves[a])),
        const SizedBox(width: 10),
        Expanded(child: _Shelf(data: _shelves[a + 1])),
      ],
    );
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [row(0), const SizedBox(height: 14), row(2)],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.data});

  final (String, List<(TapePalette, double)>) data;

  @override
  Widget build(BuildContext context) {
    final (name, spines) = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(name, style: AppText.suit(700, 12.5)),
        ),
        const SizedBox(height: 6),
        Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.shelfBoardTop, AppColors.shelfBoardBottom],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, (p, h)) in spines.indexed) ...[
                if (i > 0) const SizedBox(width: 2),
                _SmallSpine(palette: p, height: h),
              ],
            ],
          ),
        ),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.shelfPlank,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(3),
            ),
            boxShadow: [
              // 0 4px 6px -4px rgba(0,0,0,.3)
              BoxShadow(
                color: AppColors.black.withValues(alpha: .3),
                offset: const Offset(0, 4),
                blurRadius: 6,
                spreadRadius: -4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 작은 테이프 등 (18 너비, 띠 3px, 라벨 top 11 · bottom 6)
class _SmallSpine extends StatelessWidget {
  const _SmallSpine({required this.palette, required this.height});

  final TapePalette palette;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: height,
      decoration: BoxDecoration(
        color: palette.shell,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(2),
          bottom: Radius.circular(1),
        ),
      ),
      child: Stack(
        children: [
          // inset -2px 0 0 rgba(0,0,0,.14)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 2,
            child: ColoredBox(color: AppColors.black.withValues(alpha: .14)),
          ),
          Positioned(
            left: 3,
            right: 3,
            top: 5,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.band,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            left: 3,
            right: 3,
            top: 11,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.labelPaper,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
