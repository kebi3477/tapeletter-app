import 'package:flutter/material.dart';

import '../../../domain/models/tape_type.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/tape_widget.dart';
import '../../core/ui/tappable.dart';

/// 녹음 대기 화면의 테이프 캐러셀 (높이 226, 트랙 top 46).
///
/// 좌우로 50px 넘게 밀면 옆 테이프로 넘어간다. 끝에서는 0.35배 저항.
/// 트랙은 `translateX(가운데 − index×244 + dx)`, 칸 너비 264, Tape는 scale(.825).
class TapeCarousel extends StatefulWidget {
  const TapeCarousel({
    super.key,
    required this.selected,
    required this.owned,
    required this.enabled,
    required this.onSelect,
    required this.onBuy,
    required this.packL,
    required this.packR,
    required this.spinning,
    this.showChrome = true,
  });

  final TapeType selected;

  /// 종류별 보유 수. 15초는 무제한이라 보지 않는다.
  final int Function(TapeType) owned;

  /// 대기 상태에서만 밀 수 있다.
  final bool enabled;
  final ValueChanged<TapeType> onSelect;

  /// 0개 알약을 눌렀을 때 (상점으로)
  final ValueChanged<TapeType> onBuy;

  /// 가운데 테이프의 릴 (녹음 진행률)
  final double packL;
  final double packR;
  final bool spinning;

  /// 개수 알약과 옆 테이프를 보일지 (`showChrome` — 녹음 중·멈춤에는 숨김).
  /// 옆 테이프는 `op: on ? 1 : (rec||paused) ? 0 : .4` (opacity .3s)
  final bool showChrome;

  static const double height = 226;
  static const double slot = 264;
  static const double step = 244;
  static const double threshold = 50;
  static const double rubber = .35;

  @override
  State<TapeCarousel> createState() => _TapeCarouselState();
}

class _TapeCarouselState extends State<TapeCarousel> {
  double _dx = 0;
  bool _swiping = false;

  static const _ids = TapeType.values;

  void _end() {
    final i = _ids.indexOf(widget.selected);
    final ni = _dx < -TapeCarousel.threshold
        ? (i + 1).clamp(0, 2)
        : _dx > TapeCarousel.threshold
        ? (i - 1).clamp(0, 2)
        : i;
    setState(() {
      _swiping = false;
      _dx = 0;
    });
    // 옆 테이프로 넘어가면 선택 햅틱 (길이 표시를 눌러 넘길 때와 같다)
    if (ni != i) Haptic.selection.fire();
    widget.onSelect(_ids[ni]);
  }

  /// 테이프 칸의 위치와, 그 위로 올라간 개수 알약의 거리
  static const _itemTop = 46.0;
  static const _pillOffset = 38.0;

  bool _locked(int i) =>
      i >= 0 && !_ids[i].isUnlimited && widget.owned(_ids[i]) <= 0;

  @override
  Widget build(BuildContext context) {
    final ti = _ids.indexOf(widget.selected);
    var dx = _dx;
    if ((ti == 0 && dx > 0) || (ti == 2 && dx < 0)) dx *= TapeCarousel.rubber;

    return LayoutBuilder(
      builder: (context, box) {
        // 390 기준 63 = (390 − 264) / 2
        final center = (box.maxWidth - TapeCarousel.slot) / 2;
        final target = center - ti * TapeCarousel.step + dx;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.enabled
              ? (_) => setState(() {
                  _swiping = true;
                  _dx = 0;
                })
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (d) => setState(() => _dx += d.delta.dx)
              : null,
          onHorizontalDragEnd: widget.enabled ? (_) => _end() : null,
          onHorizontalDragCancel: widget.enabled ? _end : null,
          child: SizedBox(
            height: TapeCarousel.height,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: target),
              duration: _swiping ? Duration.zero : AppMotion.carousel,
              curve: AppMotion.snap,
              builder: (context, x, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < _ids.length; i++)
                    Positioned(
                      left: x + i * TapeCarousel.step,
                      top: _itemTop,
                      width: TapeCarousel.slot,
                      height: 168,
                      child: _CarouselItem(
                        type: _ids[i],
                        on: i == ti,
                        count: widget.owned(_ids[i]),
                        packL: i == ti
                            ? widget.packL
                            : TapePalette.of(_ids[i]).packFull,
                        packR: i == ti ? widget.packR : TapePalette.packEmpty,
                        spinning: i == ti && widget.spinning,
                        showPill: widget.showChrome,
                        hideOthers: !widget.showChrome,
                      ),
                    ),
                  // 0개인 가운데 테이프의 알약(+)을 누르는 자리. 알약은 테이프 칸 위로
                  // 삐져나와 있어(top −38) 칸 안에서는 눌리지 않으므로, 같은 자리에 따로 둔다.
                  if (_locked(ti) && widget.showChrome)
                    Positioned(
                      left: x + ti * TapeCarousel.step,
                      top: _itemTop - _pillOffset,
                      width: TapeCarousel.slot,
                      height: AppSizes.pill,
                      child: Semantics(
                        button: true,
                        label: '${TapePalette.of(_ids[ti]).name} 테이프 사기',
                        child: Tappable(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onBuy(_ids[ti]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CarouselItem extends StatelessWidget {
  const _CarouselItem({
    required this.type,
    required this.on,
    required this.count,
    required this.packL,
    required this.packR,
    required this.spinning,
    required this.showPill,
    required this.hideOthers,
  });

  final TapeType type;
  final bool on;
  final int count;
  final double packL;
  final double packR;
  final bool spinning;
  final bool showPill;
  final bool hideOthers;

  @override
  Widget build(BuildContext context) {
    final locked = !type.isUnlimited && count <= 0;
    // transition: transform .3s, opacity .3s
    return AnimatedScale(
      scale: on ? 1 : .8,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
      child: AnimatedOpacity(
        opacity: on
            ? 1
            : hideOthers
            ? 0
            : .4,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (showPill)
              Positioned(
                left: 0,
                right: 0,
                top: -38,
                // 0개인 가운데 테이프의 알약만 누를 수 있다 (pointer-events) — 누르는 자리는 캐러셀이 둔다
                child: Center(
                  child: _CountPill(type: type, count: count),
                ),
              ),
            IgnorePointer(
              child: ScaledBox(
                scale: AppSizes.carouselScale,
                size: AppSizes.tape,
                child: TapeWidget(
                  palette: TapePalette.of(type),
                  packL: packL,
                  packR: packR,
                  spinning: spinning,
                ),
              ),
            ),
            if (locked)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.lockVeil,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 개수 알약 (높이 28, 최소 너비 44, 패딩 0 14, `800 13px`).
class _CountPill extends StatelessWidget {
  const _CountPill({required this.type, required this.count});

  final TapeType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final zero = !type.isUnlimited && count <= 0;
    final ink = zero ? AppColors.red : AppColors.paper;
    final pill = Container(
      height: AppSizes.pill,
      constraints: const BoxConstraints(minWidth: 44),
      // + 원은 margin-right:-8px로 오른쪽 패딩을 파고든다.
      padding: EdgeInsets.only(left: 14, right: zero ? 6 : 14),
      decoration: BoxDecoration(
        color: zero ? AppColors.redTint : AppColors.ink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (type.isUnlimited)
            SvgIcon(AppIcons.infinity, width: 18, height: 10, color: ink)
          else
            Text(
              '$count개',
              style: AppText.suit(800, 13, color: ink, tabularNums: true),
            ),
          if (zero) ...[
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '+',
                style: AppText.suit(700, 14, height: 1, color: AppColors.paper),
              ),
            ),
          ],
        ],
      ),
    );
    return pill;
  }
}
