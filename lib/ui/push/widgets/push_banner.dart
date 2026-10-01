import 'package:flutter/material.dart';

import '../../auth/widgets/permission_screens.dart' show PushCard;
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../view_model/push_view_model.dart';
import '../../core/ui/tappable.dart';

/// 앱 안 푸시 배너 (`pushOn`) — 위에서 `bannerIn .45s`로 내려오고 6초 뒤 사라진다.
/// 위로 밀면 치운다(iOS 알림처럼). 디자인에는 없는 앱 동작이다.
class PushBannerHost extends StatelessWidget {
  const PushBannerHost({super.key, required this.viewModel});

  final PushViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final m = viewModel.banner;
        if (m == null) return const SizedBox.shrink();
        final top = MediaQuery.viewPaddingOf(context).top;
        return Positioned(
          left: 10,
          right: 10,
          top: top > 8 ? top : 8,
          child: _SlideDown(
            key: ValueKey(viewModel.serial),
            onDismissed: viewModel.dismissBanner,
            child: Semantics(
              button: true,
              child: Tappable(
                onTap: viewModel.tapBanner,
                child: PushCard(
                  title: m.title,
                  body: m.body,
                  background: AppColors.pushBanner,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideDown extends StatefulWidget {
  const _SlideDown({super.key, required this.child, required this.onDismissed});

  final Widget child;
  final VoidCallback onDismissed;

  @override
  State<_SlideDown> createState() => _SlideDownState();
}

class _SlideDownState extends State<_SlideDown> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  /// 손가락으로 위로 민 거리(px, 0 이하). 놓으면 제자리로 돌아오거나 위로 빠진다.
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );
  bool _leaving = false;

  @override
  void dispose() {
    _c.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    if (_leaving) return;
    // 아래로는 조금만 따라오게 한다
    final next = _drag.value + d.delta.dy;
    _drag.value = next > 0 ? next * .3 : next;
  }

  Future<void> _end(DragEndDetails d, double height) async {
    if (_leaving) return;
    final v = d.primaryVelocity ?? 0;
    if (_drag.value < -height * .3 || v < -400) {
      _leaving = true;
      await _drag.animateTo(
        -(height + 80),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      widget.onDismissed();
    } else {
      await _drag.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: AppMotion.snap,
      );
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onVerticalDragUpdate: _update,
    onVerticalDragEnd: (d) => _end(d, context.size?.height ?? 80),
    child: AnimatedBuilder(
      animation: Listenable.merge([_c, _drag]),
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _drag.value),
        child: FractionalTranslation(
          translation: Offset(
            0,
            -1.3 * (1 - AppMotion.snap.transform(_c.value)),
          ),
          child: child,
        ),
      ),
      child: widget.child,
    ),
  );
}
