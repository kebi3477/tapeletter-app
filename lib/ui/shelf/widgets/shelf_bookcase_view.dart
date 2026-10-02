import 'package:flutter/material.dart';

import '../../../domain/models/shelf.dart';
import '../../../domain/models/tape_item.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/mini_tape.dart';
import '../view_model/shelf_view_model.dart';
import '../../core/ui/animations.dart';
import 'shelf_drag.dart';
import 'shelf_list_view.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

/// 책꽂이 보기 — 템플릿 `isShelf` 블록. 선반마다 등 30×108 카세트를 3px 간격으로.
///
/// 목록과 같은 드래그(`rowDown` / `dragMove` / `dragEnd`)를 쓴다. 가로 배치라 `data-col`로
/// x 좌표의 앞·뒤를 정하고, 선반 전체(`g.dropEnd`)에 놓으면 맨 뒤에 들어간다.
class ShelfBookcase extends StatelessWidget {
  const ShelfBookcase({
    super.key,
    required this.viewModel,
    required this.drag,
    required this.onOpen,
    required this.onEditGroup,
  });

  final ShelfViewModel viewModel;
  final ShelfDragController drag;
  final void Function(TapeItem item) onOpen;
  final void Function(ShelfGroup group) onEditGroup;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final s = vm.shelf;
    final dt = vm.dragging ? vm.dropTarget : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 도착한 소포 (v10.2): 같은 카드 안 가로 스크롤 상자 64×44. 끌 수 없다.
              if (vm.parcels.isNotEmpty)
                ParcelSection(
                  count: vm.parcels.length,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  headerPadding: EdgeInsets.zero,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, x) in vm.parcels.indexed) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Tappable(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onOpen(x),
                              child: _InboxItem(
                                item: x,
                                dragging: false,
                                landed: false,
                                before: false,
                                after: false,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              SectionHeader(
                name: ShelfViewModel.unsortedName,
                count: vm.unsortedCountText,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              ),
              // 분류 안 함 줄 (`inboxEnd`, 놓을 곳이면 `#FDECE9`)
              // 칸 여백 12에서 `margin: 0 -8px` → 양옆 4
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: DropZone(
                  controller: drag,
                  target: DropTarget(null, s.unsorted.length),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: dt != null && dt.groupId == null
                          ? AppColors.redTint
                          : AppColors.redTint.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: vm.openedUnsorted.isEmpty
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                keepAll('뜯은 테이프 중 칸에 넣지 않은 테이프가 여기 모여요'),
                                style: AppText.suit(
                                  500,
                                  13.5,
                                  color: AppColors.textFaint,
                                ),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (k, (i, x))
                                    in vm.openedUnsorted.indexed) ...[
                                  if (k > 0) const SizedBox(width: 12),
                                  DropZone(
                                    controller: drag,
                                    target: DropTarget(null, i),
                                    col: true,
                                    child: DragRowGestures(
                                      controller: drag,
                                      item: x,
                                      onTap: () => onOpen(x),
                                      child: _InboxItem(
                                        item: x,
                                        dragging: vm.draggingId == x.id,
                                        landed: vm.landedId == x.id,
                                        before:
                                            dt?.groupId == null &&
                                            dt?.index == i,
                                        after:
                                            dt?.groupId == null &&
                                            i == s.unsorted.length - 1 &&
                                            dt?.index == s.unsorted.length,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              if (vm.coachOn)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _CoachMark(onOk: vm.dismissCoach),
                ),
            ],
          ),
        ),
        for (final g in s.groups)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropZone(
                  controller: drag,
                  target: DropTarget(g.id, 0),
                  child: Tappable(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onEditGroup(g),
                    child: SectionHeader(
                      name: g.name,
                      count: vm.groupCountText(g),
                      groupCount: true,
                      countFull: vm.groupFull(g),
                      padding: const EdgeInsets.only(bottom: 10),
                    ),
                  ),
                ),
                DropZone(
                  controller: drag,
                  target: DropTarget(g.id, g.items.length),
                  child: _Board(
                    groupId: g.id,
                    items: g.items,
                    vm: vm,
                    drag: drag,
                    hot: dt != null && dt.groupId == g.id,
                    onOpen: onOpen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 책꽂이 코치마크 (`coachOn`) — "테이프를 원하는 칸으로 끌어 보세요" / 알겠어요
class _CoachMark extends StatelessWidget {
  const _CoachMark({required this.onOk});

  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.row),
        ),
        child: Row(
          children: [
            const _CoachIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keepAll('테이프를 원하는 칸으로 끌어 보세요'),
                    style: AppText.suit(700, 14.5, color: AppColors.paper),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    keepAll('길게 누르면 집을 수 있어요'),
                    style: AppText.suit(
                      500,
                      12.5,
                      color: AppColors.paper.withValues(alpha: .72),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Semantics(
              button: true,
              child: Tappable(
                behavior: HitTestBehavior.opaque,
                onTap: onOk,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        '알겠어요',
                        style: AppText.suit(700, 13.5, color: AppColors.paper),
                      ),
                    ),
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

/// 52×40 — 선반 선과 등 두 개, 테이프가 선반으로 옮겨 가는 `coachMove 2.2s`
class _CoachIcon extends StatefulWidget {
  const _CoachIcon();

  @override
  State<_CoachIcon> createState() => _CoachIconState();
}

class _CoachIconState extends State<_CoachIcon>
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
    final faint = AppColors.paper.withValues(alpha: .35);
    return SizedBox(
      width: 52,
      height: 40,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          for (final (left, h) in const [(36.0, 24.0), (44.0, 20.0)])
            Positioned(
              left: left,
              bottom: 3,
              width: 7,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: faint,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              // coachMove: 0–15% 제자리 · 55–80% (22, 17) · 100% 사라짐 (ease-in-out)
              final t = _c.value;
              double move;
              var op = 1.0;
              if (t <= .15) {
                move = 0;
              } else if (t <= .55) {
                move = Curves.easeInOut.transform((t - .15) / .4);
              } else {
                move = 1;
                if (t > .8) op = 1 - Curves.easeInOut.transform((t - .8) / .2);
              }
              return Positioned(
                left: 2 + 22 * move,
                top: 4 + 17 * move,
                child: Opacity(opacity: op, child: child),
              );
            },
            child: Container(
              width: 18,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 분류 안 함 칸: 64×44 소포 또는 미니 테이프 + 이름.
/// 끄는 중이면 흐려지고(.3), 놓을 자리면 양옆에 레드 선, 옮긴 직후 `glow 1.2s`.
class _InboxItem extends StatelessWidget {
  const _InboxItem({
    required this.item,
    required this.dragging,
    required this.landed,
    required this.before,
    required this.after,
  });

  final TapeItem item;
  final bool dragging;
  final bool landed;
  final bool before;
  final bool after;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dragging ? .3 : 1,
      child: _Glow(
        on: landed,
        radius: 6,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                SizedBox(
                  width: 64,
                  height: 44,
                  child: item.opened
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8, top: 6),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: MiniTape(palette: TapePalette.of(item.type)),
                          ),
                        )
                      : const _BigParcel(),
                ),
                const SizedBox(height: 7),
                Text(item.from, style: AppText.suit(700, 12.5)),
              ],
            ),
            if (before)
              const Positioned(left: -7, top: 0, child: _DropLine(44)),
            if (after)
              const Positioned(right: -7, top: 0, child: _DropLine(44)),
          ],
        ),
      ),
    );
  }
}

/// 놓을 자리 표시 (2px 레드 세로선)
class _DropLine extends StatelessWidget {
  const _DropLine(this.height);

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.red,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}

/// `@keyframes glow{0%,60%{box-shadow:0 0 0 3px #E5402B}100%{box-shadow:0 0 0 0 rgba(229,64,43,0)}}` 1.2s ease
class _Glow extends StatefulWidget {
  const _Glow({required this.on, required this.radius, required this.child});

  final bool on;
  final double radius;
  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.on) _c.forward();
  }

  @override
  void didUpdateWidget(_Glow old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) _c.forward(from: 0);
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
        final t = Curves.ease.transform(_c.value);
        final k = !_c.isAnimating
            ? 0.0
            : t <= .6
            ? 1.0
            : 1 - (t - .6) / .4;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: k <= 0
                ? const []
                : [
                    BoxShadow(
                      color: AppColors.red.withValues(alpha: k),
                      spreadRadius: 3 * k,
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 64×44 크라프트 소포 (테이프 십자 8px)
class _BigParcel extends StatelessWidget {
  const _BigParcel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kraft,
        borderRadius: BorderRadius.circular(4),
        boxShadow: AppShadows.bigParcel,
      ),
      child: const Stack(
        children: [
          Positioned(
            left: 28,
            top: 0,
            bottom: 0,
            width: 8,
            child: ColoredBox(color: AppColors.kraftTape),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 18,
            height: 8,
            child: ColoredBox(color: AppColors.kraftTape),
          ),
        ],
      ),
    );
  }
}

/// 선반: 136 높이 판(`#FBF9F5`→`#F2EDE3`) + 10px 선반 판(`#DDD3C2`).
/// 놓을 칸이면 안쪽 2px 레드 테두리 (`g.hot`, `box-shadow .15s`).
class _Board extends StatelessWidget {
  const _Board({
    required this.groupId,
    required this.items,
    required this.vm,
    required this.drag,
    required this.hot,
    required this.onOpen,
  });

  final String groupId;
  final List<TapeItem> items;
  final ShelfViewModel vm;
  final ShelfDragController drag;
  final bool hot;
  final void Function(TapeItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final dt = vm.dragging ? vm.dropTarget : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 136,
          foregroundDecoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(
              color: hot ? AppColors.red : AppColors.red.withValues(alpha: 0),
              width: 2,
            ),
          ),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.shelfBoardTop, AppColors.shelfBoardBottom],
            ),
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      keepAll('아직 비어 있어요'),
                      style: AppText.suit(
                        500,
                        13.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  clipBehavior: Clip.none,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        SizedBox(
                          height: 136,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: DropZone(
                              controller: drag,
                              target: DropTarget(groupId, i),
                              col: true,
                              child: DragRowGestures(
                                controller: drag,
                                item: items[i],
                                onTap: () => onOpen(items[i]),
                                child: _Spine(
                                  item: items[i],
                                  dragging: vm.draggingId == items[i].id,
                                  landed: vm.landedId == items[i].id,
                                  before:
                                      dt?.groupId == groupId && dt?.index == i,
                                  after:
                                      dt?.groupId == groupId &&
                                      i == items.length - 1 &&
                                      dt?.index == items.length,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        Container(
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.shelfPlank,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
            boxShadow: AppShadows.plank,
          ),
        ),
      ],
    );
  }
}

/// 카세트 등 30×108: 위 띠, 가운데 세로쓰기 보낸 사람 이름. 누르는 동안 −8px 들린다(hover).
class _Spine extends StatefulWidget {
  const _Spine({
    required this.item,
    required this.dragging,
    required this.landed,
    required this.before,
    required this.after,
  });

  final TapeItem item;
  final bool dragging;
  final bool landed;
  final bool before;
  final bool after;

  @override
  State<_Spine> createState() => _SpineState();
}

class _SpineState extends State<_Spine> {
  bool _up = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _up = true),
      onPointerUp: (_) => setState(() => _up = false),
      onPointerCancel: (_) => setState(() => _up = false),
      child: Opacity(
        opacity: widget.dragging ? .3 : 1,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: Offset(0, _up && !widget.dragging ? -8 / 108 : 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _Glow(
                on: widget.landed,
                radius: 3,
                child: TapeSpine(item: widget.item),
              ),
              // 놓을 자리: 왼쪽 −3 / 오른쪽 −3, top −8 ~ bottom 0
              if (widget.before)
                const Positioned(left: -3, top: -8, child: _DropLine(116)),
              if (widget.after)
                const Positioned(right: -3, top: -8, child: _DropLine(116)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카세트 등 그림 30×108 — 껍데기(shell) 색, 위 띠(band), 라벨에 세로쓰기 보낸 사람 이름.
/// 책꽂이와 책꽂이 드래그 고스트([SpineGhost])가 같이 쓴다.
class TapeSpine extends StatelessWidget {
  const TapeSpine({super.key, required this.item});

  static const double width = 30;
  static const double height = 108;

  final TapeItem item;

  @override
  Widget build(BuildContext context) =>
      // 테이프 등 그림은 시스템 글자 크기와 상관없이 고정 (v10.4)
      MediaQuery.withNoTextScaling(child: _spine());

  Widget _spine() {
    final p = TapePalette.of(item.type);
    return CustomPaint(
      foregroundPainter: _SpineShade(),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: p.shell, borderRadius: _spineRadius),
        child: Stack(
          children: [
            Positioned(
              left: 5,
              right: 5,
              top: 8,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.band,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            Positioned(
              left: 5,
              right: 5,
              top: 19,
              bottom: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.labelPaper,
                  borderRadius: BorderRadius.circular(2),
                ),
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.center,
                child: _VerticalText(item.from),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _spineRadius = BorderRadius.vertical(
  top: Radius.circular(3),
  bottom: Radius.circular(1),
);

/// 책꽂이 보기에서 끌 때 손가락을 따라다니는 테이프 등 — 목록 고스트([DragGhost])와 같은
/// −1.5° 회전, scale 1.03, 그림자(`AppShadows.dragGhost`).
class SpineGhost extends StatelessWidget {
  const SpineGhost({super.key, required this.item});

  final TapeItem item;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -1.5 * 3.141592653589793 / 180,
        child: Transform.scale(
          scale: 1.03,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: _spineRadius,
              boxShadow: AppShadows.dragGhost,
            ),
            child: TapeSpine(item: item),
          ),
        ),
      ),
    );
  }
}

/// `inset -3px 0 0 rgba(0,0,0,.14), inset 2px 0 0 rgba(255,255,255,.1)`
class _SpineShade extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(1),
      bottomRight: const Radius.circular(1),
    );
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 3, 0, 3, size.height),
      Paint()..color = AppColors.black.withValues(alpha: .14),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 2, size.height),
      Paint()..color = AppColors.paper.withValues(alpha: .1),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpineShade old) => false;
}

/// `writing-mode: vertical-rl` — 한글은 글자를 세운 채 위에서 아래로.
class _VerticalText extends StatelessWidget {
  const _VerticalText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      maxHeight: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final ch in text.characters)
            Text(ch, style: AppText.suit(700, 11, height: 1.15)),
        ],
      ),
    );
  }
}
